defmodule AnnotAt.Atproto.Slingshot do
  @moduledoc """
  Very simple Slingshot client for fetching public records and resolving identities.
  """

  # GET https://slingshot.cove.town/xrpc/blue.microcosm.identity.resolveMiniDoc?identifier=<did>
  # GET https://slingshot.cove.town/xrpc/com.atproto.repo.getRecord?repo=<did>&collection=<collection>&rkey=<rkey>

  @resolve "/xrpc/blue.microcosm.identity.resolveMiniDoc"
  @get_record "/xrpc/com.atproto.repo.getRecord"
  @user_agent "annotat (+https://annot.at)"
  @receive_timeout 5_000

  def resolve_identity(did, slingshot_url \\ Application.get_env(:annot_at, :slingshot_url)) do
    url = "#{slingshot_url}#{@resolve}"

    with {:ok,
          %{
            "handle" => handle,
            "did" => did,
            "pds" => pds
          }} <- get(url, %{identifier: did}) do
      if handle == "handle.invalid" do
        {:error, :invalid}
      else
        {:ok, %{handle: handle, pds: pds, did: did}}
      end
    end
  end

  def get_record(
        did,
        collection,
        rkey,
        slingshot_url \\ Application.get_env(:annot_at, :slingshot_url)
      ) do
    get(
      "#{slingshot_url}#{@get_record}",
      %{
        repo: did,
        collection: collection,
        rkey: rkey
      },
      retry: false
    )
  end

  def get(url, params, opts \\ []) do
    headers = [{"user-agent", @user_agent}]

    opts =
      Keyword.merge(
        [
          params: params,
          headers: headers,
          receive_timeout: @receive_timeout
        ],
        opts
      )

    case Req.get(url, opts) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_status, status}}

      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end
end
