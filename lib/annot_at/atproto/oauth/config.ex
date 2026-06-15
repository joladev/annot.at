defmodule AnnotAt.Atproto.OAuth.Config do
  @moduledoc """
  Reads the atproto OAuth client configuration: the client id, redirect URI,
  scope, and the ES256 signing key.

  Confgiured under `config :annot_at, AnnotAt.Atproto.OAuth.Config` with
  `:scope` and `:signing_jwk` (a JSON-encoded private JWK).
  """

  @client_metadata_path "/oauth-client-metadata.json"
  @callback_path "/auth/callback"

  @doc """
  The client id: the URL where the client metadata document is published.
  """
  def client_id, do: base_url() <> @client_metadata_path

  @doc """
  OAuth callback URL.
  """
  def redirect_uri, do: base_url() <> @callback_path

  @doc """
  The scopes requested at login.
  """
  def scope, do: fetch!(:scope)

  @doc """
  The ES256 signing key.
  """
  @spec signing_key() :: JOSE.JWK.t()
  def signing_key do
    :signing_jwk
    |> fetch!()
    |> Jason.decode!()
    |> JOSE.JWK.from()
  end

  defp base_url, do: AnnotAtWeb.Endpoint.url()

  defp fetch!(key) do
    :annot_at
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(key)
  end
end
