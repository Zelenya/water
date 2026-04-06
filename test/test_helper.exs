ExUnit.start()

if Process.whereis(Water.Repo) do
  Ecto.Adapters.SQL.Sandbox.mode(Water.Repo, :manual)
end
