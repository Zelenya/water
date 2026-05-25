defmodule WaterWeb.SessionController do
  use WaterWeb, :controller

  import Plug.BasicAuth, only: [request_basic_auth: 2]

  alias WaterWeb.Plugs.BasicAuth

  @logout_challenge_session_key "logout_challenge_pending"
  @realm "Water"

  def show(conn, _params) do
    if get_session(conn, @logout_challenge_session_key) do
      conn
      |> delete_session(@logout_challenge_session_key)
      |> request_basic_auth(realm: @realm)
      |> halt()
    else
      redirect(conn, to: ~p"/")
    end
  end

  def delete(conn, _params) do
    conn
    |> BasicAuth.clear_authenticated_session()
    |> put_session(@logout_challenge_session_key, true)
    |> redirect(to: ~p"/logout")
  end
end
