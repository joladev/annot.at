defmodule AnnotAtWeb.LoginLiveTest do
  use AnnotAtWeb.ConnCase, async: true
  use Mimic

  import Phoenix.LiveViewTest

  alias AnnotAt.Atproto.Directory
  alias AnnotAt.Atproto.OAuth.Login

  test "renders the sign-in form", %{conn: conn} do
    {:ok, lv, _html} = live(conn, ~p"/login")

    assert has_element?(lv, "input#handle")
    assert has_element?(lv, "button[type=submit]")
  end

  test "submitting a valid handle redirects to the authorization URL", %{conn: conn} do
    authorization_url = "https://bsky.social/oauth/authorize?x=1"

    expect(Login, :start_login, fn "jola.dev" ->
      {:ok, authorization_url}
    end)

    {:ok, lv, _html} = live(conn, ~p"/login")

    lv
    |> form("form", %{"handle" => "jola.dev"})
    |> render_submit()

    assert_redirect(lv, authorization_url)
  end

  test "submitting an invalid handle shows an error", %{conn: conn} do
    expect(Login, :start_login, fn _ ->
      {:error, :invalid_handle}
    end)

    {:ok, lv, _html} = live(conn, ~p"/login")

    html =
      lv
      |> form("form", %{"handle" => "nope"})
      |> render_submit()

    assert html =~ "That doesn&#39;t look like a valid handle"
  end

  test "typing suggests matching handles", %{conn: conn} do
    expect(Directory, :search_handles, fn "jola" ->
      [%{handle: "jola.dev", display_name: "Johanna", avatar: nil}]
    end)

    {:ok, lv, _html} = live(conn, ~p"/login")

    html =
      lv
      |> form("form", %{"handle" => "jola"})
      |> render_change()

    assert html =~ "jola.dev"
  end

  test "selecting a suggestion shows matched profile avatar", %{conn: conn} do
    avatar = "https://cdn.example/jola.jpg"

    expect(Directory, :search_handles, fn "jola" ->
      [%{handle: "jola.dev", display_name: "Johanna", avatar: avatar}]
    end)

    {:ok, lv, _html} = live(conn, ~p"/login")

    lv
    |> form("form", %{"handle" => "jola"})
    |> render_change()

    lv
    |> element("#suggestion-0")
    |> render_click()

    refute has_element?(lv, "#handle-listbox")
    assert has_element?(lv, "img[src='#{avatar}']")
  end
end
