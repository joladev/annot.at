defmodule AnnotAt.Atproto.HTTP do
  @moduledoc """
  HTTP transport boundary for atproto identify resolution.

  Fetches raw bodies and decodes JSON explicity, so behavior does not depend
  on server-provided content types (DID documents are seomtimes served as
  `application/did+ld+json, which generic encoders miss). Stubbed via Mimic in
  tests. This module has no unit tests of its own.
  """

  @receive_timeout 10_000
  @type body :: nil | {:json, map()} | {:raw, binary(), String.t()}

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

  @doc """
  POSTs `form` as `application/x-www-form-urlencoded` with `headers`, returning
  the raw status, body, and response headers.

  Unlike `get_json/1` this neither treats non-2xx as an error nor decodes the
  body: atproto OAuth endpoints return meaningful JSON and a `DPoP-Nonce` header
  on 4xx responses, which the caller must inspect to drive the none retry.
  """
  @spec post_form(String.t(), keyword() | map(), [{String.t(), String.t()}]) ::
          {:ok,
           %{status: pos_integer(), body: binary(), headers: %{optional(binary()) => [binary()]}}}
          | {:error, {:transport, term()}}
  def post_form(url, form, headers \\ []) do
    options = [
      url: url,
      form: form,
      headers: headers,
      decode_body: false,
      receive_timeout: @receive_timeout
    ]

    case Req.post(options) do
      {:ok, %Req.Response{status: status, body: body, headers: resp_headers}} ->
        {:ok, %{status: status, body: body, headers: resp_headers}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  @doc """
  Performs an HTTP request with the given method, headers, and optional
  body, returning the raw status, body, and response headers.
  """
  @spec request(String.t(), String.t(), [{String.t(), String.t()}], body()) ::
          {:ok,
           %{status: pos_integer(), body: binary(), headers: %{optional(binary()) => [binary()]}}}
          | {:error, {:transport, term()}}
  def request(method, url, headers, body \\ nil) do
    options = [
      method: method_atom(method),
      url: url,
      headers: headers,
      decode_body: false,
      receive_timeout: @receive_timeout
    ]

    case Req.request(put_body(options, body)) do
      {:ok, %Req.Response{status: status, body: resp_body, headers: resp_headers}} ->
        {:ok, %{status: status, body: resp_body, headers: resp_headers}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  defp method_atom("GET"), do: :get
  defp method_atom("POST"), do: :post

  defp get_body(url) when is_binary(url) do
    case Req.get(url, decode_body: false, receive_timeout: @receive_timeout) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_status, status}}
      {:error, reason} -> {:error, {:transport, reason}}
    end
  end

  defp put_body(options, nil), do: options
  defp put_body(options, {:json, json}), do: Keyword.put(options, :json, json)

  defp put_body(options, {:raw, body, content_type}) do
    options
    |> Keyword.put(:body, body)
    |> Keyword.update!(:headers, &[{"content-type", content_type} | &1])
  end
end
