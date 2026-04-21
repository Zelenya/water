defmodule WaterWeb.Plugs.BasicAuth do
  @moduledoc """
  Basic-auth gate for the garden UI.

  This app does not have a separate user-account system. Instead, configured
  basic-auth usernames are matched against active `Households.Member` records in
  the default household.

  We keep a long signed browser session, because I don't to relogin
  and I don't care if someone maliciously waters my garden.
  """

  import Plug.BasicAuth, only: [parse_basic_auth: 1, request_basic_auth: 2]
  import Plug.Conn

  alias Water.Households
  alias Water.Households.Member

  @behaviour Plug
  @active_member_session_key "active_member_id"
  @auth_session_key "basic_auth_session"
  @auth_session_salt "basic auth session"
  @realm "Water"
  @session_max_age Application.compile_env!(:water, :authenticated_session_max_age)

  @type all_credentials() :: %{usernames: [String.t()], password: String.t()}
  @type authenticated_member() :: {:ok, Member.t(), String.t()} | :error

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    household = Households.get_default_household!()
    credentials = hardcoded_credentials()

    # Check the existing signed session, then fall back to the Basic Auth header
    case authenticate_member(conn, household, credentials) do
      {:ok, %Member{} = member, username} ->
        # Even if the session is valid, we want to refresh it on every request
        persist_authenticated_member(conn, member, username, credentials.password)

      :error ->
        challenge(conn)
    end
  end

  @spec hardcoded_credentials() :: all_credentials()
  defp hardcoded_credentials do
    basic_auth = Application.fetch_env!(:water, :basic_auth)

    %{
      usernames: Keyword.fetch!(basic_auth, :usernames),
      password: Keyword.fetch!(basic_auth, :password)
    }
  end

  @spec authenticate_member(Plug.Conn.t(), Water.Households.Household.t(), all_credentials()) ::
          authenticated_member()
  defp authenticate_member(conn, household, credentials) do
    # The session path is the steady state. Basic Auth is the bootstrap path.
    case session_member(conn, household, credentials) do
      {:ok, %Member{} = member, username} ->
        {:ok, member, username}

      :error ->
        %{usernames: usernames, password: password} = credentials
        # Validate the browser-provided Basic Auth credentials and map them onto the
        # currently active household member with the same name.
        with {request_username, request_password} <- parse_basic_auth(conn),
             username <- normalize_username(request_username),
             true <- valid_username?(usernames, username),
             true <- Plug.Crypto.secure_compare(password, request_password),
             %Member{} = member <- Households.find_active_member_by_name(household, username) do
          {:ok, member, username}
        else
          _error -> :error
        end
    end
  end

  @spec session_member(Plug.Conn.t(), Water.Households.Household.t(), all_credentials()) ::
          authenticated_member()
  defp session_member(conn, household, %{usernames: usernames, password: password}) do
    # Trust the browser session only after verifying the signed token and re-resolving the member
    with token when is_binary(token) <- get_session(conn, @auth_session_key),
         {:ok, username} <- verify_session_auth(conn, token, password),
         true <- valid_username?(usernames, username),
         %Member{} = member <- Households.find_active_member_by_name(household, username) do
      {:ok, member, username}
    else
      _error ->
        :error
    end
  end

  @spec verify_session_auth(Plug.Conn.t(), String.t(), String.t()) :: {:ok, String.t()} | :error
  defp verify_session_auth(conn, token, password) do
    case Phoenix.Token.verify(conn, salt(password), token, max_age: @session_max_age) do
      {:ok, username} when is_binary(username) -> {:ok, normalize_username(username)}
      _error -> :error
    end
  end

  @spec persist_authenticated_member(Plug.Conn.t(), Member.t(), String.t(), String.t()) ::
          Plug.Conn.t()
  # Refresh both auth/session values on every successful request so the
  # persistent session and the LiveView-facing active member stay aligned.
  defp persist_authenticated_member(conn, %Member{} = member, username, password) do
    conn
    |> put_session(@auth_session_key, sign_session_auth(conn, username, password))
    |> put_session(@active_member_session_key, member.id)
  end

  @spec sign_session_auth(Plug.Conn.t(), String.t(), String.t()) :: String.t()
  defp sign_session_auth(conn, username, password) do
    Phoenix.Token.sign(conn, salt(password), username)
  end

  @spec salt(String.t()) :: String.t()
  defp salt(password), do: @auth_session_salt <> ":" <> password

  @spec challenge(Plug.Conn.t()) :: Plug.Conn.t()
  # Clear auth-related session state before asking the browser to authenticate again.
  defp challenge(conn) do
    conn
    |> delete_session(@auth_session_key)
    |> delete_session(@active_member_session_key)
    |> request_basic_auth(realm: @realm)
    |> halt()
  end

  @spec normalize_username(String.t()) :: String.t()
  defp normalize_username(username) do
    username
    |> String.trim()
    |> String.downcase()
  end

  @spec valid_username?([String.t()], String.t()) :: boolean()
  defp valid_username?(configured_usernames, username) do
    # Usernames come from static config, but we still compare them in constant
    # time to avoid avoidable timing leaks in the auth path.
    Enum.any?(configured_usernames, &Plug.Crypto.secure_compare(&1, username))
  end
end
