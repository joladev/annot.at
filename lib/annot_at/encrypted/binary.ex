defmodule AnnotAt.Encrypted.Binary do
  @moduledoc false

  use Cloak.Ecto.Binary, vault: AnnotAt.Vault
end
