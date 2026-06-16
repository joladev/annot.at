defmodule AnnotAt.Atproto.XRPC do
  @moduledoc """
  DPoP-authenticated XRPC calls to a session's PDS.

  Each request carriers `Authorization: DPoP <token` and a DPoP proof bound to
  the acess token `ath`. The PDS issues its own DPoP nonces, so a request is
  attempted once and retried with the nonce the PDS returns. Token refresh and
  persistence are the caller's concerns, not this module's.
  """

  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.OAuth.DPoP
  alias AnnotAt.Atproto.OAuth.Session

  @type error ::
          {:transport, term()}
          | :invalid_json
          | :missing_dpop_nonce
          | {:xrpc_error, pos_integer(), map()}

  @doc """
  Performs and authenticated XRPC query against the session's PDS.
  """
  @spec query(Session.t(), String.t(), keyword()) :: {:ok, map()} | {:error, error()}
  def query(%Session{} = session, method, params \\ []) do
    request(
      session,
      "GET",
      session.pds_endpoint <> "/xrpc/" <> method <> query_string(params),
      nil
    )
  end

  defp request(%Session{} = session, http_method, url, body, nonce \\ nil) do
    proof =
      DPoP.proof(session.dpop_key, http_method, url,
        nonce: nonce,
        access_token: session.access_token
      )

    headers = [{"authorization", "DPoP #{session.access_token}"}, {"dpop", proof}]

    with {:ok, %{status: status, body: raw, headers: resp_headers}} <-
           HTTP.request(http_method, url, headers, body),
         {:ok, decoded} <- decode_json(raw) do
      cond do
        status in 200..299 ->
          {:ok, decoded}

        needs_nonce?(status, resp_headers) ->
          retry_with_nonce(session, http_method, url, body, resp_headers)

        true ->
          {:error, {:xrpc_error, status, decoded}}
      end
    end
  end

  defp retry_with_nonce(session, http_method, url, body, headers) do
    case nonce_header(headers) do
      nil -> {:error, :missing_dpop_nonce}
      nonce -> request(session, http_method, url, body, nonce)
    end
  end

  defp needs_nonce?(401, headers) do
    headers
    |> Map.get("www-authenticate")
    |> Enum.any?(&String.contains?(&1, "use_dpop_nonce"))
  end

  defp needs_nonce?(_status, _headers), do: false

  defp nonce_header(headers) do
    case Map.get(headers, "dpop-nonce") do
      [nonce | _] -> nonce
      _ -> nil
    end
  end

  defp decode_json(raw) do
    case Jason.decode(raw) do
      {:ok, json} -> {:ok, json}
      _ -> {:error, :invalid_json}
    end
  end

  defp query_string([]), do: ""
  defp query_string(params), do: "?" <> URI.encode_query(params)
end
