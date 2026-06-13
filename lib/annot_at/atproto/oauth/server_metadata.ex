defmodule AnnotAt.Atproto.OAuth.ServerMetadata do
  @moduledoc """
  Parses authorization server metadata (`/.well-known/oauth-authorization-server`)
  per the atproto OAuth profile.

  Validates the document's internal correctness only. The caller must also
  verify that the `issuer` matches the origin the document was fetched from.
  """

  @enforce_keys [
    :issuer,
    :authorization_endpoint,
    :token_endpoint,
    :par_endpoint,
    :scopes_supported
  ]
  defstruct @enforce_keys ++ [:revocation_endpoint]

  @type t :: %__MODULE__{
          issuer: String.t(),
          authorization_endpoint: String.t(),
          token_endpoint: String.t(),
          par_endpoint: String.t(),
          revocation_endpoint: String.t() | nil,
          scopes_supported: [String.t()]
        }

  @doc """
  Validates a decoded metadata document and extracts the fields we use.

  Checks every requirement the atproto OAuth spec places on authorization
  servers, except `none` in `token_endpoint_auth_methods_supported`, which
  only matters to public clients.

  Uses a manual validation layer instead of Ecto.Changeset because I want to
  split this out eventually.
  """
  @spec parse(map()) :: {:ok, t()} | {:error, {:missing | :invalid, String.t()}}
  def parse(metadata) when is_map(metadata) do
    with :ok <- origin_url(metadata, "issuer"),
         :ok <- https_url(metadata, "authorization_endpoint"),
         :ok <- https_url(metadata, "token_endpoint"),
         :ok <- https_url(metadata, "pushed_authorization_request_endpoint"),
         :ok <- member(metadata, "response_types_supported", "code"),
         :ok <- member(metadata, "grant_types_supported", "authorization_code"),
         :ok <- member(metadata, "grant_types_supported", "refresh_token"),
         :ok <- member(metadata, "code_challenge_methods_supported", "S256"),
         :ok <- member(metadata, "token_endpoint_auth_methods_supported", "private_key_jwt"),
         :ok <- member(metadata, "token_endpoint_auth_signing_alg_values_supported", "ES256"),
         :ok <- member(metadata, "scopes_supported", "atproto"),
         :ok <- member(metadata, "dpop_signing_alg_values_supported", "ES256"),
         :ok <- flag(metadata, "require_pushed_authorization_requests"),
         :ok <- flag(metadata, "authorization_response_iss_parameter_supported"),
         :ok <- flag(metadata, "client_id_metadata_document_supported") do
      {:ok,
       %__MODULE__{
         issuer: Map.fetch!(metadata, "issuer"),
         authorization_endpoint: Map.fetch!(metadata, "authorization_endpoint"),
         token_endpoint: Map.fetch!(metadata, "token_endpoint"),
         par_endpoint: Map.fetch!(metadata, "pushed_authorization_request_endpoint"),
         revocation_endpoint: Map.get(metadata, "revocation_endpoint"),
         scopes_supported: Map.fetch!(metadata, "scopes_supported")
       }}
    end
  end

  defp origin_url(metadata, field) do
    with :ok <- https_url(metadata, field) do
      url = Map.get(metadata, field)

      case URI.parse(url) do
        %URI{path: nil, query: nil, fragment: nil, userinfo: nil} ->
          :ok

        _ ->
          {:error, {:invalid, field}}
      end
    end
  end

  defp https_url(metadata, field) do
    case Map.get(metadata, field) do
      nil ->
        {:error, {:missing, field}}

      value when is_binary(value) ->
        case URI.parse(value) do
          %URI{scheme: "https", host: host} when is_binary(host) and host != "" -> :ok
          _ -> {:error, {:invalid, field}}
        end

      _ ->
        {:error, {:invalid, field}}
    end
  end

  defp member(metadata, field, value) do
    case Map.get(metadata, field) do
      nil ->
        {:error, {:missing, field}}

      list when is_list(list) ->
        if value in list do
          :ok
        else
          {:error, {:invalid, field}}
        end

      _ ->
        {:error, {:invalid, field}}
    end
  end

  defp flag(metadata, field) do
    case Map.get(metadata, field) do
      true -> :ok
      nil -> {:error, {:missing, field}}
      _ -> {:error, {:invalid, field}}
    end
  end
end
