defmodule AnnotAt.Atproto.OAuth.Discovery do
  @moduledoc """
  Discovers the authorization server for a PDS and validates the binding
  between them, per the atproto OAuth profile.

  The PDS publishes `/.well-known/oauth-protected-resource` naming its
  authorization server, that server's metadata `issuer` must in turn match
  the URL it was discovered at. Both directions are checked before the
  metadata is trusted.
  """

  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.OAuth.ServerMetadata

  @protected_resource_path "/.well-known/oauth-protected-resource"
  @auth_server_path "/.well-known/oauth-authorization-server"

  @doc """
  Resolves a PDS endpoint to its authorization server metadata.
  """
  @spec discover(String.t()) ::
          {:ok, ServerMetadata.t()}
          | {:error,
             :resource_mismatch
             | :no_authorization_server
             | :issuer_mismatch
             | {:http_status, pos_integer()}
             | {:transport, term()}
             | :invalid_json
             | {:missing, String.t()}
             | {:invalid, String.t()}}
  def discover(pds_endpoint) when is_binary(pds_endpoint) do
    with {:ok, resource} <- HTTP.get_json(pds_endpoint <> @protected_resource_path),
         {:ok, issuer} <- authorization_server(resource, pds_endpoint),
         {:ok, metadata} <- HTTP.get_json(issuer <> @auth_server_path),
         {:ok, server} <- ServerMetadata.parse(metadata),
         :ok <- verify_issuer(server, issuer) do
      {:ok, server}
    end
  end

  defp authorization_server(resource, pds_endpoint) do
    with :ok <- verify_resource(resource, pds_endpoint) do
      case Map.get(resource, "authorization_servers") do
        # There has to be exactly one issuer according to the spec.
        [issuer] when is_binary(issuer) -> {:ok, issuer}
        _ -> {:error, :no_authorization_server}
      end
    end
  end

  defp verify_resource(%{"resource" => resource}, resource), do: :ok
  defp verify_resource(_resource, _pds_endpoint), do: {:error, :resource_mismatch}

  defp verify_issuer(%ServerMetadata{issuer: issuer}, issuer), do: :ok
  defp verify_issuer(_server, _issuer), do: {:error, :issuer_mismatch}
end
