defmodule AnnotAt.Atproto.HTTP do
  @moduledoc """
  HTTP transport boundary for atproto identify resolution.

  Fetches raw bodies and decodes JSON explicity, so behavior does not depend
  on server-provided content types (DID documents are seomtimes served as
  `application/did+ld+json, which generic encoders miss). Stubbed via Mimic in
  tests. This module has no unit tests of its own.
  """

  @receive_timeout 10_000

  @doc """
  GETs `url`, required a 2xx response, and decodes the body as a JSON object.
  """
  @spec get_json(String.t()) ::
          {:ok, map()}
          | {:error, {:http_status, pos_integer()} | {:transport, term()} | :invalid_json}
  def get_json(url) when is_binary(url) do
    with {:ok, body} <- get_body(url) do
      case Jason.decode(body) do
        {:ok, %{} = json} -> {:ok, json}
        _ -> {:error, :invalid_json}
      end
    end
  end

  @doc """
  GETs `url`, requires a 2xx response, and returns the raw response body.
  """
  @spec get_text(String.t()) ::
          {:ok, String.t()} | {:error, {:http_status, pos_integer()} | {:transport, term()}}
  def get_text(url) when is_binary(url) do
    get_body(url)
  end

  defp get_body(url) when is_binary(url) do
    case Req.get(url, decode_body: false, receive_timeout: @receive_timeout) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, {:transport, reason}}
    end
  end
end
