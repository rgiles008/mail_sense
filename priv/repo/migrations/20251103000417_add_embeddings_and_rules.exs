defmodule MailSense.Repo.Migrations.AddEmbeddingsAndRules do
  use Ecto.Migration

  def change do
    alter table(:categories) do
      add :exemplar, :text
      add :rules, :map, default: %{}, null: false
      add :gmail_label_id, :string
    end

    create table(:email_embeddings, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :email_id, references(:emails, type: :uuid, column: :id, on_delete: :delete_all),
        null: false

      add :content_hash, :string, null: false
      add :embedding, :vector, size: 1536, null: false
      timestamps()
    end

    create unique_index(:email_embeddings, [:email_id])

    create table(:category_embeddings, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :category_id, references(:categories, type: :uuid, column: :id, on_delete: :delete_all),
        null: false

      add :embedding, :vector, size: 1536, null: false
      timestamps()
    end

    create unique_index(:category_embeddings, [:category_id])
  end
end
