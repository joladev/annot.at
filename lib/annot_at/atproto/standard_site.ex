defmodule AnnotAt.Atproto.StandardSite do
  @moduledoc """
  Writes standard.site records (publication, documents) to a user's repo
  via the authenticated `Client`, uploading any images as blobs first.
  """

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto.OAuth.Client
  alias AnnotAt.Atproto.StandardSite.Document
  alias AnnotAt.Atproto.StandardSite.Publication

  @publication "site.standard.publication"
  @document "site.standard.document"

  @doc """
  Creates or updates the user's publication record (one per repo, rkey `self`).
  """
  @spec put_publication(integer(), Publication.t()) :: {:ok, map()} | {:error, term()}
  def put_publication(user_id, %Publication{} = publication) do
    with {:ok, user} <- fetch_user(user_id),
         {:ok, icon} <- upload_image(user_id, publication.icon) do
      put_record(user, @publication, "self", publication_record(publication, icon))
    end
  end

  @doc """
  Creates or updates a document record.
  """
  @spec put_document(integer(), Document.t()) :: {:ok, map()} | {:error, term()}
  def put_document(user_id, %Document{} = document) do
    with {:ok, user} <- fetch_user(user_id),
         {:ok, cover} <- upload_image(user_id, document.cover_image) do
      put_record(user, @document, document.rkey, document_record(document, cover))
    end
  end

  @doc """
  The AT-URI of the user's publication record, used as a document's `site`.
  """
  @spec publication_uri(String.t()) :: String.t()
  def publication_uri(did), do: "at://#{did}/#{@publication}/self"

  defp fetch_user(user_id) do
    case Accounts.get_user(user_id) do
      nil -> {:error, :no_session}
      user -> {:ok, user}
    end
  end

  defp upload_image(_user_id, nil), do: {:ok, nil}

  defp upload_image(user_id, {bytes, content_type}) do
    with {:ok, %{"blob" => blob}} <- Client.upload_blob(user_id, bytes, content_type) do
      {:ok, blob}
    end
  end

  defp put_record(user, collection, rkey, record) do
    body = %{repo: user.did, collection: collection, rkey: rkey, record: record}
    Client.procedure(user.id, "com.atproto.repo.putRecord", body)
  end

  defp publication_record(p, icon) do
    %{"$type" => @publication, "name" => p.name, "url" => p.url}
    |> put_optional("description", p.description)
    |> put_optional("icon", icon)
  end

  defp document_record(d, cover_image) do
    %{
      "$type" => @document,
      "site" => d.site,
      "title" => d.title,
      "publishedAt" => DateTime.to_iso8601(d.published_at)
    }
    |> put_optional("path", d.path)
    |> put_optional("updatedAt", iso8601(d.updated_at))
    |> put_optional("description", d.description)
    |> put_optional("textContent", d.text_content)
    |> put_optional("tags", d.tags)
    |> put_optional("coverImage", cover_image)
  end

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp put_optional(map, _key, nil), do: map
  defp put_optional(map, key, value), do: Map.put(map, key, value)
end
