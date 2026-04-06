defmodule WaterWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use WaterWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :integration

      # The default endpoint for testing
      @endpoint WaterWeb.Endpoint

      use WaterWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import WaterWeb.ConnCase
    end
  end

  setup tags do
    Water.DataCase.setup_sandbox(tags)
    {:ok, conn: authenticated_conn(Phoenix.ConnTest.build_conn())}
  end

  @spec authenticated_conn(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def authenticated_conn(conn, username \\ "a") do
    credentials = Application.fetch_env!(:water, :basic_auth)
    password = Keyword.fetch!(credentials, :password)
    token = Plug.BasicAuth.encode_basic_auth(username, password)

    Plug.Conn.put_req_header(conn, "authorization", token)
  end

  @spec unauthenticated_conn() :: Plug.Conn.t()
  def unauthenticated_conn do
    Phoenix.ConnTest.build_conn()
  end
end
