import Config

parse_integer_env = fn env_name, default ->
  value = System.get_env(env_name, default)

  case Integer.parse(value) do
    {integer, ""} ->
      integer

    _ ->
      raise """
      environment variable #{env_name} must be an integer, got: #{inspect(value)}
      """
  end
end

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :water, Water.Repo,
  username: System.get_env("DATABASE_USER", "postgres"),
  password: System.get_env("DATABASE_PASSWORD", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: parse_integer_env.("DATABASE_PORT", "5432"),
  database:
    "#{System.get_env("DATABASE_NAME", "water_test")}#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :water, WaterWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "PCGk+oBoUqW1wY1gHpgcUY2Kpe5EOxZHqX97GtAJityMKvVLUKeyynbATYgpKb4R",
  server: false

# In test we don't send emails
config :water, Water.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

config :phoenix_test, :endpoint, WaterWeb.Endpoint

# Use the stub weather fetcher in test
config :water, :weather_fetcher, Water.TestWeatherFetcher
