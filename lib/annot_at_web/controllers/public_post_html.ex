defmodule AnnotAtWeb.PublicPostHTML do
  use AnnotAtWeb, :html
  import AnnotAtWeb.DocumentComponents

  embed_templates "public_post_html/*"
end
