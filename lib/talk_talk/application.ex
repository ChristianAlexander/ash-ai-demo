defmodule TalkTalk.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      TalkTalkWeb.Telemetry,
      TalkTalk.Repo,
      {DNSCluster, query: Application.get_env(:talk_talk, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TalkTalk.PubSub},
      # Start a worker by calling: TalkTalk.Worker.start_link(arg)
      # {TalkTalk.Worker, arg},
      # Start to serve requests, typically the last entry
      TalkTalkWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :talk_talk]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TalkTalk.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TalkTalkWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
