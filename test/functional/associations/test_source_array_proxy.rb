require 'test_helper'

class SourceArrayProxyTest < Test::Unit::TestCase
  context "description" do
    setup do
      class ::List
        include MongoMapper::Document
        key :name, String, :required => true
        many :users, :source => :lists
      end

      class ::User
        include MongoMapper::Document
        key :name, String, :required => true
        key :list_ids, Array
        many :lists, :in => :list_ids
      end
      User.collection.remove
      List.collection.remove
    end
    
    teardown do
      Object.send :remove_const, 'List' if defined?(::List)
      Object.send :remove_const, 'User' if defined?(::User)
    end

    should "default reader to empty array" do
      List.new.users.should == []
    end

    should "list any objects that reference it" do
      user = User.new(:name => 'Gigli')
      list = user.lists.create(:name => 'Worst Films of the Decade')
      list.users.should include(user)
    end

    should "allow adding to association like it was an array" do
      list = List.new(:name => 'List 1')
      list.users << User.new(:name => 'Adam')
      list.users.push User.new(:name => 'Brian')
      list.users.concat User.new(:name => 'Carolyn')
      list.users.size.should == 3
    end

    should "ignore adding duplicate ids" do
      list = List.new(:name => 'List')
      user = User.create(:name => 'Brian')
      list.users << user
      list.users << user
      list.users << user
      list.users.size.should == 1
      user.list_ids.should == [list.id]
    end

    context "replacing the association" do
      setup do
        @list = List.new(:name => 'List')
        @user_created_via_list = @list.users.create(:name => 'Robert')
        @user = User.new(:name => 'Brian')
        @list_created_via_user = @user.lists.create(:name => 'List to keep')
      end

      should "remove the owner from any docs it just replaced" do
        @user_created_via_list.lists.should include(@list)
        @list.users = [@user]
        @list.save.should be_true
        @list.reload
        @user_created_via_list.lists.should_not include(@list)
      end

      should "reference new association docs" do
        @list.users.should == [@user_created_via_list]
        @list.users.should_not include(@user)
        @list.users[0].name.should_not == 'Brian'
        @list.users = [@user]
        @list.save.should be_true
        @list.reload
        @list.users.should include(@user)
        @list.users[0].name.should == 'Brian'
        @list.users.should == [@user]

        @list.users.size.should == 1
      end

      should "not reference replaced association docs" do
        @list.users[0].name.should == @user_created_via_list.name
        @list.users = [@user]
        @list.save.should be_true
        @list.reload
        @list.users.should_not include(@user_created_via_list)
      end

      should "append the owner to the corresponding many association of each replacement doc" do
        @user.list_ids.should == [@list_created_via_user.id]
        @list.users = [@user]
        @list.save.should be_true
        @list.reload
        @user.list_ids.should == [@list_created_via_user.id, @list.id]
      end
    end

    context "adding to association" do
      should "update the target association's in_array" do
        list = List.new(:name => 'List')
        user = User.create(:name => 'Brian')
        user.lists.should == []
        list.users << user
        user.lists.should == [list]
        user.list_ids.should == [list.id]
      end
    end

    context "create" do
      setup do
        @list = List.create(:name => 'Tail Section')
        @user = @list.users.create(:name => 'Mr. Echo')
      end

      should "add list id to the user's list_ids" do
        @user.list_ids.should include(@list.id)
      end

      should "persist id addition to key in database" do
        @user.reload
        @user.list_ids.should include(@list.id)
      end

      should "add doc to association" do
        @list.users.should include(@user)
        @user.lists.should include(@list)
      end

      should "save doc" do
        @user.should_not be_new
      end
    end

    context "create!" do
      setup do
        @list = List.create(:name => 'Generic Users')
        @user = @list.users.create!(:name => 'John Doe')
      end

      should "add list id to the user's list_ids" do
        @user.list_ids.should include(@list.id)
      end

      should "persist id addition to key in database" do
        @user.reload
        @user.list_ids.should include(@list.id)
      end

      should "add doc to association" do
        @list.users.should include(@user)
        @user.lists.should include(@list)
      end

      should "save doc" do
        @user.should_not be_new
      end

      should "raise exception if invalid" do
        assert_raises(MongoMapper::DocumentNotValid) do
          @list.users.create!
        end
      end
    end

    context "Finding scoped to an association" do
      setup do
        @list1 = List.create(:name => 'Maintainers')
        @list2 = List.create(:name => 'Patchers')
        @user1 = @list1.users.create!(:name => 'John', :position => 1)
        @user2 = @list1.users.create!(:name => 'Mr. N', :position => 2)
        @user3 = @list2.users.create!(:name => 'Brian', :position => 1)
      end

      context "all" do
        should "work" do
          @list1.users.find(:all, :order => :position.asc).should == [@user1, @user2]
          @list1.users.all(:order => :position.asc).should == [@user1, @user2]
        end

        should "work with conditions" do
          @list1.users.find(:all, :name => 'John').should == [@user1]
          @list1.users.all(:name => 'John').should == [@user1]
        end
      end

      context "first" do
        should "work" do
          @list1.users.find(:first, :order => 'position').should == @user1
          @list1.users.first(:order => 'position').should == @user1
        end

        should "work with conditions" do
          @list1.users.find(:first, :position => 2).should == @user2
          @list1.users.first(:position => 2).should == @user2
        end
      end

      context "last" do
        should "work" do
          @list1.users.find(:last, :order => 'position').should == @user2
          @list1.users.last(:order => 'position').should == @user2
        end

        should "work with conditions" do
          @list1.users.find(:last, :position => 2, :order => 'position').should == @user2
          @list1.users.last(:position => 2, :order => 'position').should == @user2
        end
      end

      context "with one id" do
        should "work for id in association" do
          @list1.users.find(@user1.id).should == @user1
        end

        should "not work for id not in association" do
          @list1.users.find(@user3.id).should be_nil
        end

        should "raise error when using ! and not found" do
          assert_raises MongoMapper::DocumentNotFound do
            @list1.users.find!(@user3.id)
          end
        end
      end

      context "with multiple ids" do
        should "work for ids in association" do
          @list1.users.find(@user1.id, @user2.id).should == [@user1, @user2]
        end

        should "not work for ids not in association" do
          @list1.users.find(@user1.id, @user2.id, @user3.id).should == [@user1, @user2]
        end
      end

      context "with #paginate" do
        setup do
          @users = @list1.users.paginate(:per_page => 1, :page => 1, :order => 'position')
        end

        should "return total pages" do
          @users.total_pages.should == 2
        end

        should "return total entries" do
          @users.total_entries.should == 2
        end

        should "return the object" do
          @users.map(&:name).should == ['John']
        end
      end

      context "dynamic finders" do
        should "work with single key" do
          @list1.users.find_by_name('John').should == @user1
          @list1.users.find_by_name!('John').should == @user1
          @list1.users.find_by_name('Brian').should be_nil
        end

        should "work with multiple keys" do
          @list1.users.find_by_name_and_position('John', 1).should == @user1
          @list1.users.find_by_name_and_position!('John', 1).should == @user1
          @list1.users.find_by_name_and_position('Brian', 1).should be_nil
        end

        should "raise error when using ! and not found" do
          assert_raises(MongoMapper::DocumentNotFound) do
            @list1.users.find_by_name!('Brian')
          end
        end

        context "find_or_create_by" do
          should "not create document if found" do
            lambda {
              user = @list1.users.find_or_create_by_name('John')
              user.should == @user1
            }.should_not change { User.count }
          end

          should "create document if not found" do
            lambda {
              user = @list1.users.find_or_create_by_name('Mr. Nunemaker')
              @list1.users.should include(user)
            }.should change { User.count }
          end
        end
      end
    end

    context "count" do
      setup do
        @list1 = List.create(:name => 'Gladiators')
        @list2 = List.create(:name => 'Spectators')
        @user1 = @list1.users.create!(:name => 'Maximus')
        @user2 = @list1.users.create!(:name => 'Sparticus')
        @user3 = @list2.users.create!(:name => 'Marcus')
      end

      should "return number of objects referencing list's id" do
        @list1.users.count.should == 2
        @list2.users.count.should == 1
      end

      should "return correct count when given criteria" do
        @list1.users.count(:name => 'Maximus').should == 1
        @list2.users.count(:name => 'Maximus').should == 0
      end
    end

    context "removing documents" do
      setup do
        @list1 = List.create(:name => 'Gladiators')
        @list2 = List.create(:name => 'Spectators')
        @user1 = @list1.users.create!(:name => 'Maximus', :position => 1)
        @user2 = @list1.users.create!(:name => 'Sparticus', :position => 2)
        @user3 = @list2.users.create!(:name => 'Marcus', :position => 1)
      end

      context "destroy_all" do
        should "work" do
          @list1.users.count.should == 2
          @list1.users.destroy_all
          @list1.users.count.should == 0
          User.all.should == [@user3]
        end

        should "work with conditions" do
          @list1.users.count.should == 2
          @list1.users.destroy_all(:name => 'Maximus')
          @list1.users.count.should == 1
          User.all.should == [@user2, @user3]
        end
      end

      context "delete_all" do
        should "work" do
          @list1.users.count.should == 2
          @list1.users.delete_all
          @list1.users.count.should == 0
          User.all.should == [@user3]
        end

        should "work with conditions" do
          @list1.users.count.should == 2
          @list1.users.delete_all(:name => 'Maximus')
          @list1.users.count.should == 1
          User.all.should == [@user2, @user3]
        end
      end

      should "work with nullify" do
        @list1.users.count.should == 2
        lambda {
          @list1.users.nullify
        }.should_not change { User.count }
        @list1.users.count.should == 0
      end
    end
  end
end
