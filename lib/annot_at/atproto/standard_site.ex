defmodule AnnotAt.Atproto.StandardSite do
  @moduledoc """
  Writes standard.site records (publication, documents) to a user's repo
  via the authenticated `Client`, uploading any images as blobs first.
  """

  alias AnnotAt.Accounts
  alias AnnotAt.Atproto.HTTP
  alias AnnotAt.Atproto.OAuth.Client
  alias AnnotAt.Atproto.StandardSite.Document
  alias AnnotAt.Atproto.StandardSite.Publication

  @publication "site.standard.publication"
  @document "site.standard.document"
  @wellknown_path "/.well-known/site.standard.publication"

  @doc """
  Creates or updates the user's publication record.
  """
  @spec put_publication(integer(), String.t(), Publication.t()) :: {:ok, map()} | {:error, term()}
  def put_publication(user_id, rkey, %Publication{} = publication) do
    with {:ok, user} <- fetch_user(user_id),
         {:ok, icon} <- upload_image(user_id, publication.icon) do
      put_record(user, @publication, rkey, publication_record(publication, icon))
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

  def delete_document(user_id, rkey) do
    with {:ok, user} <- fetch_user(user_id) do
      Client.procedure(user.id, "com.atproto.repo.deleteRecord", %{
        repo: user.did,
        collection: @document,
        rkey: rkey
      })
    end
  end

  @doc """
  The AT-URI of the user's publication record, used as a document's `site`.
  """
  @spec publication_uri(String.t(), String.t()) :: String.t()
  def publication_uri(did, rkey), do: "at://#{did}/#{@publication}/#{rkey}"

  @doc """
  Verifies the website hosts the publication's AT-URI at its well-known path,
  proving control of the domain.
  """
  @spec verify_ownership(String.t(), String.t()) ::
          :ok
          | {:error,
             :mismatch | :not_found | {:http_status, pos_integer()} | {:transport, term()}}
  def verify_ownership(url, at_uri) do
    url = wellknown_url(url)

    case HTTP.get_text(url) do
      {:ok, body} ->
        if String.trim(body) == at_uri do
          :ok
        else
          {:error, :mismatch}
        end

      {:error, {:http_status, 404}} ->
        {:error, :not_found}

      {:error, _reason} = error ->
        error
    end
  end

  @spec list_publications(integer()) ::
          {:ok, [%{rkey: String.t(), url: String.t() | nil, name: String.t() | nil}]}
          | {:error, :no_session}
  def list_publications(user_id) do
    with {:ok, user} <- fetch_user(user_id),
         {:ok, %{"records" => records}} <-
           Client.query(user.id, "com.atproto.repo.listRecords",
             repo: user.did,
             collection: @publication
           ) do
      {:ok, Enum.map(records, &to_existing/1)}
    end
  end

  @doc """
  Reads the user's publication document.
  """
  @spec get_publication(integer(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_publication(user_id, rkey) do
    with {:ok, user} <- fetch_user(user_id),
         {:ok, %{"value" => value}} <-
           Client.query(user.id, "com.atproto.repo.getRecord",
             repo: user.did,
             collection: @publication,
             rkey: rkey
           ) do
      {:ok, value}
    end
  end

  @doc """
  Builds the publication document we create, from page metadata.
  """
  @spec draft_publication(String.t(), %{title: String.t() | nil, description: String.t() | nil}) ::
          map()
  def draft_publication(url, %{title: title, description: description}) do
    %{
      "$type" => @publication,
      "name" => title,
      "url" => url,
      "description" => description,
      "preferences" => %{"showInDiscover" => true}
    }
  end

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

  defp wellknown_url(url) do
    uri = URI.parse(url)

    URI.to_string(%{
      uri
      | path: @wellknown_path,
        query: nil,
        fragment: nil
    })
  end

  defp to_existing(%{"uri" => uri, "value" => value}) do
    rkey =
      uri
      |> String.split("/")
      |> List.last()

    %{rkey: rkey, url: value["url"], name: value["name"]}
  end
end
