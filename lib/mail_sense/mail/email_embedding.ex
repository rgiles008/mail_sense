defmodule MailSense.Mail.EmailEmbedding do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "email_embeddings" do
    field :content_hash, :string
    field :embedding, :binary

    belongs_to :email, MailSense.Mail.Email

    timestamps()
  end

  def changeset(embeddings, attrs) do
    embeddings
    |> cast(attrs, [:content_hash, :embeddings])
    |> validate_required([:email_id, :content_hash, :embedding])
    |> unique_constraint(:email_id)
  end
end
