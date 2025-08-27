class CreateJobs < ActiveRecord::Migration[8.0]
  def change
    create_table :jobs do |t|
      t.string :title
      t.string :company
      t.string :location
      t.text :description
      t.string :url
      t.string :job_category
      t.string :salary
      t.datetime :posted_date

      t.timestamps
    end
  end
end
