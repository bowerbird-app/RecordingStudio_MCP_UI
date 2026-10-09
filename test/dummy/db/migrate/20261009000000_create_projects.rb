class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "draft"
      t.integer :revision, null: false, default: 1
      t.timestamps
    end
  end
end
