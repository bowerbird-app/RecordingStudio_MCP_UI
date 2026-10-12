class AddPageWidgetContent < ActiveRecord::Migration[8.1]
  def change
    change_table :pages, bulk: true do |t|
      t.text :summary
      t.jsonb :sections, null: false, default: []
      t.jsonb :links, null: false, default: []
      t.jsonb :topics, null: false, default: []
      t.string :sort, null: false, default: "label"
      t.string :direction, null: false, default: "asc"
      t.integer :revision, null: false, default: 1
    end
  end
end
