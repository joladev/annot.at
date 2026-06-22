defmodule AnnotAt.Publishing do
  @moduledoc """
  Context for a user's sites. Each site mirrors a `site.standard.publication`
  record in the user's atproto rep. Each user can have many sites, one for
  each actual website they control. Only created after verification.
  """

  import Ecto.Query, only: [from: 2]

  alias AnnotAt.Accounts.Scope
  alias AnnotAt.Accounts.User
  alias AnnotAt.Atproto.TID
  alias AnnotAt.Publishing.Site
  alias AnnotAt.Repo

  @spec list_sites(Scope.t()) :: [Site.t()]
  def list_sites(%Scope{user: %User{id: user_id}}) do
    Repo.all(from s in Site, where: s.user_id == ^user_id, order_by: [desc: s.inserted_at])
  end

  def list_sites_for_url(%Scope{user: %User{id: user_id}}, url) do
    Repo.all(
      from s in Site,
        where: s.user_id == ^user_id and s.url == ^url,
        order_by: [desc: s.inserted_at]
    )
  end

  def get_site!(%Scope{user: %User{id: user_id}}, id) do
    Repo.get_by!(Site, id: id, user_id: user_id)
  end

  def create_site(%Scope{user: %User{id: user_id}}, url) do
    %Site{user_id: user_id}
    |> Site.changeset(%{url: url})
    |> Repo.insert()
  end

  def use_new_publication(%Scope{user: %User{id: user_id}}, %Site{} = site) do
    verify_user_ownership!(site, user_id)
    rkey = TID.now()

    site
    |> Ecto.Changeset.change(%{rkey: rkey})
    |> Repo.update()
  end

  def use_existing_publication(%Scope{user: %User{id: user_id}}, %Site{} = site, rkey) do
    verify_user_ownership!(site, user_id)

    site
    |> Ecto.Changeset.change(%{rkey: rkey, published_at: DateTime.utc_now(:second)})
    |> Repo.update()
  end

  def mark_verified(%Scope{user: %User{id: user_id}}, %Site{} = site) do
    verify_user_ownership!(site, user_id)

    site
    |> Ecto.Changeset.change(%{
      verified_at: DateTime.utc_now(:second)
    })
    |> Repo.update()
  end

  def mark_published(%Scope{user: %User{id: user_id}}, %Site{} = site) do
    verify_user_ownership!(site, user_id)

    site
    |> Ecto.Changeset.change(%{
      published_at: DateTime.utc_now(:second)
    })
    |> Repo.update()
  end

  def update_site(%Scope{user: %User{id: user_id}}, %Site{} = site, attrs) do
    verify_user_ownership!(site, user_id)

    site
    |> Site.changeset(attrs)
    |> Repo.update()
  end

  defp verify_user_ownership!(%Site{user_id: user_id}, user_id), do: :ok
  defp verify_user_ownership!(%Site{}, _user_id), do: raise(Ecto.NoResultsError, queryable: Site)
end
