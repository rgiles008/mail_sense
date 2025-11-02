defmodule MailSense.Repo.Migrations.AddGmailAccountsTable do
  use Ecto.Migration

  def change do
    create table(:gmail_accounts, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :email, :string, null: false
      add :access_token, :string, null: false
      add :refresh_token, :string, null: false
      add :expires_at, :utc_datetime

      add :user_id, references(:users, type: :uuid, column: :id, on_delete: :delete_all),
        null: false

      timestamps()
    end
  end
end
