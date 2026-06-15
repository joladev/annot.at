defmodule AnnotAt.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      AnnotAtWeb.Telemetry,
      AnnotAt.Vault,
      AnnotAt.Repo,
      {DNSCluster, query: Application.get_env(:annot_at, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AnnotAt.PubSub},
      # Start a worker by calling: AnnotAt.Worker.start_link(arg)
      # {AnnotAt.Worker, arg},
      # Start to serve requests, typically the last entry
      AnnotAtWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AnnotAt.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    AnnotAtWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
