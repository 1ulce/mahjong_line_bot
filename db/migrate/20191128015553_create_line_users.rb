class CreateLineUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :line_users do |t|
      t.string :nick_name
      t.string :line_id
      t.string :image_url
      t.timestamps
    end
  end
end
