defmodule MailSense.Repo.Migrations.AddEmailsTable do
  use Ecto.Migration

  def change do
    create table(:emails, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :gmail_message_id, :string, null: false
      add :thread_id, :string
      add :subject, :string
      add :from, :string
      add :to, :string
      add :snippet, :string
      add :internal_date, :integer
      add :ai_summary, :string
      add :ai_category_reason, :string
      add :raw_headers, :map
      add :list_unsubscribe, :map
      add :archived_at, :utc_datetime
      add :body_text, :string
      add :body_html, :string

      add :gmail_account_id,
          references(:gmail_accounts, type: :uuid, column: :id, on_delete: :delete_all),
          null: false

      add :category_id, references(:categories, type: :uuid, column: :id, on_delete: :delete_all)

      timestamps()
    end
  end
end
