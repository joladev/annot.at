defmodule AnnotAtWeb.PublicPostController do
  use AnnotAtWeb, :controller

  alias AnnotAt.Atproto
  alias AnnotAt.Atproto.StandardSite

  require Logger

  def show(conn, %{"did" => did, "rkey" => rkey}) do
    case StandardSite.get_public_document(did, rkey) do
      {:ok, doc, did_doc} ->
        render(conn, :show,
          doc: doc,
          author: author(doc, did_doc),
          cover_url: blob(did_doc.pds_endpoint, did, doc.cover_image),
          page_title: doc.title
        )

      {:error, error} ->
        Logger.warning("PublicPost: failed to get public doc", reason: error)

        conn
        |> put_status(:not_found)
        |> put_view(html: AnnotAtWeb.ErrorHTML)
        |> render(:"404")
    end
  end

  defp author(doc, did_doc) do
    case StandardSite.get_public_publication(doc.site) do
      {:ok, pub, pub_doc} ->
        %{
          avatar_url: blob(pub_doc.pds_endpoint, pub_doc.did, pub["icon"]),
          display_name: pub["name"],
          handle: did_doc.handle
        }

      {:error, _} ->
        %{display_name: nil, handle: did_doc.handle, avatar_url: nil}
    end
  end

  defp blob(_pds, _did, nil), do: nil
  defp blob(pds, did, blob), do: Atproto.blob_url(pds, did, blob)
end
