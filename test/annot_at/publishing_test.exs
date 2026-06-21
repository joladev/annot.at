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
        handle: "jola.dev",
        pds_host: "https://pds.example.com"
      })

    %{scope: Scope.for_user(user)}
  end

  test "create_site/2 creates a site with no rkey yet", %{scope: scope} do
    assert {:ok, %Site{} = site} =
             Publishing.create_site(
               scope,
               "https://example.com"
             )

    assert site.user_id == scope.user.id
    refute site.rkey
    refute site.verified_at
  end

  test "use_new_publication/2 mints and stores an rkey", %{scope: scope} do
    {:ok, site} = Publishing.create_site(scope, "https://example.com")
    assert {:ok, updated} = Publishing.use_new_publication(scope, site)
    assert updated.rkey =~ ~r/^[234567abcdefghij]/
  end

  test "use_existing_publication/3 stores the given rkey", %{scope: scope} do
    {:ok, site} = Publishing.create_site(scope, "https://example.com")
    assert {:ok, updated} = Publishing.use_existing_publication(scope, site, "3mope7jyypk22")
    assert "3mope7jyypk22" == updated.rkey
  end

  test "create_site/2 resumes the same site for a url", %{scope: scope} do
    {:ok, first} = Publishing.create_site(scope, "https://example.com/")
    {:ok, again} = Publishing.create_site(scope, "https://example.com/")
    assert first.id == again.id
    assert first.rkey == again.rkey
  end

  test "create_site/2 keeps distinct sites per url", %{scope: scope} do
    {:ok, _} = Publishing.create_site(scope, "https://one.com")
    {:ok, _} = Publishing.create_site(scope, "https://two.com")
    assert 2 == length(Publishing.list_sites(scope))
  end

  test "get_site!/2 returns the scope's site", %{scope: scope} do
    {:ok, site} = Publishing.create_site(scope, "https://example.com")
    assert Publishing.get_site!(scope, site.id).id == site.id
  end

  test "update_site/3 fills editable fields", %{scope: scope} do
    {:ok, site} = Publishing.create_site(scope, "https://example.com")

    assert {:ok, updated} =
             Publishing.update_site(scope, site, %{
               name: "Blog",
               feed_url: "https://example.com/feed.xml"
             })

    assert "Blog" == updated.name
    assert "https://example.com/feed.xml" == updated.feed_url
  end

  test "mark_verified/2 then mark_published/2 stamp the timestamps", %{scope: scope} do
    {:ok, site} = Publishing.create_site(scope, "https://example.com")
    {:ok, verified} = Publishing.mark_verified(scope, site)
    assert %DateTime{} = verified.verified_at
    {:ok, published} = Publishing.mark_published(scope, verified)
    assert %DateTime{} = published.published_at
  end

  test "scoped functions refuse a site the scope doesn't own", %{scope: scope} do
    {:ok, other} = Accounts.upsert_user(%{did: "did:plc:otheruser000000000000000"})
    other_scope = Scope.for_user(other)
    {:ok, site} = Publishing.create_site(scope, "https://example.com")

    assert_raise Ecto.NoResultsError, fn ->
      Publishing.get_site!(
        other_scope,
        site.id
      )
    end

    assert_raise Ecto.NoResultsError, fn ->
      Publishing.update_site(other_scope, site, %{name: "x"})
    end

    assert_raise Ecto.NoResultsError, fn ->
      Publishing.mark_verified(other_scope, site)
    end

    assert_raise Ecto.NoResultsError, fn ->
      Publishing.mark_published(other_scope, site)
    end
  end

  test "use_new_publication/2 mints an rkey and leaves it unpublished", %{scope: scope} do
    {:ok, site} = Publishing.create_site(scope, "https://example.com")
    assert {:ok, updated} = Publishing.use_new_publication(scope, site)
    assert updated.rkey =~ ~r/^[234567abcdefghij]/
    refute updated.published_at
  end

  test "use_existing_publication/3 stores the rkey and marks it published",
       %{scope: scope} do
    {:ok, site} = Publishing.create_site(scope, "https://example.com")
    assert {:ok, updated} = Publishing.use_existing_publication(scope, site, "3mope7jyypk22")
    assert "3mope7jyypk22" == updated.rkey
    assert %DateTime{} = updated.published_at
  end
end
