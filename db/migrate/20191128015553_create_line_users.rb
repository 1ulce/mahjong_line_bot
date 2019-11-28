class CreateLineUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :line_users do |t|

      t.timestamps
    end
  end
end
