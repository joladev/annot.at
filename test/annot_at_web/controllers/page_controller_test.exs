defmodule AnnotAtWeb.PageControllerTest do
  use AnnotAtWeb.ConnCase, async: true

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "annot.at"
  end
end
