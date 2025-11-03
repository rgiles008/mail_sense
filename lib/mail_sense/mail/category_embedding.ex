defmodule MailSense.Mail.CategoryEmbedding do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "category_embeddings" do
    field :embedding, :binary

    belongs_to :category, MailSense.Mail.Category

    timestamps()
  end

  def changeset(category_embedding, attrs) do
    category_embedding
    |> cast(attrs, [:embedding, :category_id])
    |> validate_required([:category_id, :embedding])
    |> unique_constraint(:category_id)
  end
end
