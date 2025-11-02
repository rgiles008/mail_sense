defmodule MailSense.Repo.Migrations.AddIndexingAndUniqueToTables do
  use Ecto.Migration

  def change do
    create unique_index(:users, [:email])

    create unique_index(:gmail_accounts, [:email, :user_id])

    create index(:categories, [:user_id])

    create unique_index(:emails, [:gmail_message_id])
    create index(:emails, [:category_id])
    create index(:emails, [:gmail_account_id])
  end
end
