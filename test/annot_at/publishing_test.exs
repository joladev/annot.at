defmodule AnnotAt.PublishingTest do
  use AnnotAt.DataCase, async: true

  alias AnnotAt.Accounts
  alias AnnotAt.Accounts.Scope
  alias AnnotAt.Publishing
  alias AnnotAt.Publishing.Site

  setup do
    {:ok, user} =
      Accounts.upsert_user(%{
        did: "did:plc:ewvi7nxzyoun6zhxrhs64oiz",
        handle: "alice.test",
        pds_host: "https://pds.example.com"
      })

    %{scope: Scope.for_user(user)}
  end

  test "create_site/3 persists a verified site owned by the scope", %{scope: scope} do
    assert {:ok, %Site{} = site} = Publishing.create_site(scope, "3mope7jyypk22", site_attrs())
    assert site.user_id == scope.user.id
    assert "3mope7jyypk22" == site.rkey
    assert %DateTime{} = site.verified_at

    assert [listed] = Publishing.list_sites(scope)
    assert listed.id == site.id
  end

  test "a user can hold many sites for different websites", %{scope: scope} do
    {:ok, _} = Publishing.create_site(scope, "aaa", site_attrs(%{url: "https://one.com"}))
    {:ok, _} = Publishing.create_site(scope, "bbb", site_attrs(%{url: "https://two.com"}))

    assert 2 == length(Publishing.list_sites(scope))
  end

  test "create_site/3 requires name, url and feed_url", %{scope: scope} do
    assert {:error, changeset} = Publishing.create_site(scope, "rkey", %{})
    assert %{name: _, url: _, feed_url: _} = errors_on(changeset)
  end

  test "rkey is unique per user", %{scope: scope} do
    {:ok, _} = Publishing.create_site(scope, "dup", site_attrs())
    assert {:error, changeset} = Publishing.create_site(scope, "dup", site_attrs())
    assert %{rkey: _} = errors_on(changeset)
  end

  test "get_site!/2 raises for a site the scope doesn't own", %{scope: scope} do
    {:ok, other} = Accounts.upsert_user(%{did: "did:plc:otheruser000000000000000"})
    other_scope = Scope.for_user(other)
    {:ok, site} = Publishing.create_site(scope, "scoped", site_attrs())

    assert Publishing.get_site!(scope, site.id).id == site.id

    assert_raise Ecto.NoResultsError, fn ->
      Publishing.get_site!(
        other_scope,
        site.id
      )
    end
  end

  test "update_site/3 refuses a site the scope doesn't own", %{scope: scope} do
    {:ok, other} = Accounts.upsert_user(%{did: "did:plc:otheruser000000000000000"})
    other_scope = Scope.for_user(other)
    {:ok, site} = Publishing.create_site(scope, "owned", site_attrs())

    assert_raise Ecto.NoResultsError, fn ->
      Publishing.update_site(other_scope, site, %{name: "x"})
    end
  end

  defp site_attrs(overrides \\ %{}) do
    Map.merge(
      %{name: "My Blog", url: "https://example.com", feed_url: "https://example.com/feed.xml"},
      overrides
    )
  end
end
