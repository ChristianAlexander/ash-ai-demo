import Config
config :talk_talk, Oban, testing: :manual
config :talk_talk, token_signing_secret: "UmxZa0AvM0uGAsyLhMeS1NNG5JEEw2ZM"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true]

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :talk_talk, TalkTalk.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "talk_talk_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :talk_talk, TalkTalkWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "jofPb6yarNgWop1WgALncbS0nRY+HwOiM4PczFPL0u1BqxY+T968iyoW0qWCHxlE",
  server: false

# In test we don't send emails
config :talk_talk, TalkTalk.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
