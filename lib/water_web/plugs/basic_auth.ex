defmodule WaterWeb.Plugs.BasicAuth do
  @moduledoc """
  Minimal authentication plug that binds browser credentials to a household member.

  This app does not have a separate user-account system. Instead, configured
  basic-auth usernames are matched against active `Households.Member` records in
  the default household, and the resolved member id is stored in session for
  LiveView to use as the acting identity.
  """

  import Plug.BasicAuth, only: [parse_basic_auth: 1, request_basic_auth: 2]
  import Plug.Conn

  alias Water.Households

  @behaviour Plug
  @active_member_session_key "active_member_id"
  @realm "Water"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    credentials = Application.fetch_env!(:water, :basic_auth)
    usernames = Keyword.fetch!(credentials, :usernames)
    password = Keyword.fetch!(credentials, :password)

    with {request_username, request_password} <- parse_basic_auth(conn),
         username <- normalize_username(request_username),
         true <- valid_username?(usernames, username),
         true <- Plug.Crypto.secure_compare(password, request_password),
         household <- Households.get_default_household!(),
         %{} = member <- Households.find_active_member_by_name(household, username) do
      # Persist the resolved member id so downstream LiveViews can treat "active
      # member" as session state rather than re-running auth logic in render code.
      put_session(conn, @active_member_session_key, member.id)
    else
      _error ->
        conn
        |> request_basic_auth(realm: @realm)
        |> halt()
    end
  end

  @spec normalize_username(String.t()) :: String.t()
  defp normalize_username(username) do
    username
    |> String.trim()
    |> String.downcase()
  end

  @spec valid_username?([String.t()], String.t()) :: boolean()
  defp valid_username?(configured_usernames, username) do
    Enum.any?(configured_usernames, &Plug.Crypto.secure_compare(&1, username))
  end
end
