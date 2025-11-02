defmodule MailSense.Repo.Migrations.AddCategoriesTable do
  use Ecto.Migration

  def change do
    create table(:categories, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :string

      add :user_id, references(:users, type: :uuid, column: :id, on_delete: :delete_all),
        null: false

      timestamps()
    end
  end
end
