defmodule AnnotAt.Atproto.OAuth.TokenResponse do
  @moduledoc """
  Parses token endpoint responses per the atproto OAuth profile.
  """

  @enforce_keys [
    :access_token,
    :refresh_token,
    :expires_in,
    :scope,
    :sub
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          access_token: String.t(),
          refresh_token: String.t(),
          expires_in: pos_integer(),
          scope: String.t(),
          sub: String.t()
        }

  @doc """
  Validates a decoded token response and extracts the fields we use.

  `refresh_token` and `expires_in` are optional in RFC 6749 but required
  here: background polling depends on refresh, and refresh scheduling
  depends on expiry, so a server omitting either fails at login instead
  of failing later. `token_type` must be `DPoP` (compared case-insensitively
  per RFC 6749) and carries no information once validated, so it is not
  kept on the struct.

  `sub` is only checked syntactically. The caller must verify it equals
  the DID resolved from the user's handle before trusting it.
  """
  @spec parse(map()) :: {:ok, t()} | {:error, {:missing | :invalid, String.t()}}
  def parse(response) when is_map(response) do
    with :ok <- string(response, "access_token"),
         :ok <- string(response, "refresh_token"),
         :ok <- string(response, "scope"),
         :ok <- token_type(response),
         :ok <- expires_in(response),
         :ok <- did(response, "sub") do
      {:ok,
       %__MODULE__{
         access_token: Map.fetch!(response, "access_token"),
         refresh_token: Map.fetch!(response, "refresh_token"),
         expires_in: Map.fetch!(response, "expires_in"),
         scope: Map.fetch!(response, "scope"),
         sub: Map.fetch!(response, "sub")
       }}
    end
  end

  defp string(response, field) do
    case Map.get(response, field) do
      nil -> {:error, {:missing, field}}
      value when is_binary(value) and value != "" -> :ok
      _ -> {:error, {:invalid, field}}
    end
  end

  defp token_type(response) do
    case Map.get(response, "token_type") do
      nil ->
        {:error, {:missing, "token_type"}}

      value when is_binary(value) ->
        if String.downcase(value) == "dpop" do
          :ok
        else
          {:error, {:invalid, "token_type"}}
        end

      _ ->
        {:error, {:invalid, "token_type"}}
    end
  end

  defp expires_in(response) do
    case Map.get(response, "expires_in") do
      nil -> {:error, {:missing, "expires_in"}}
      value when is_integer(value) and value > 0 -> :ok
      _ -> {:error, {:invalid, "expires_in"}}
    end
  end

  defp did(response, field) do
    with :ok <- string(response, field) do
      did = Map.fetch!(response, field)

      if String.starts_with?(did, "did:") do
        :ok
      else
        {:error, {:invalid, field}}
      end
    end
  end
end
