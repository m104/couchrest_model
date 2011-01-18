require File.expand_path("../../spec_helper", __FILE__)
require File.join(FIXTURE_PATH, 'more', 'service')
require File.join(FIXTURE_PATH, 'more', 'user')

describe 'Casted Views' do
  before(:all) do
    reset_test_db!

    # load the test cases
    #
    # CAUTION: changing the test cases will probably
    #          alter the test outcomes!
    ['Lawncare', 'Elephant Training', 'Cheese Tasting',
     'Acrobatic Training', 'Firehydrant Painting',
     'Clock Winding', 'Remote Finding', 'Chocolate Tasting',
     'Rabbit Training', 'Propeller Winding'].each do |name|
      Service.new(:name => name).save!
    end

    ['Brenda Pardone', 'Wendel Covington', 'Bradly P. Buttersby',
     'Frox', 'Jenny Hammersmithe', 'Shu Lao Chun', 'Waldo',
     'Michael Pardone', 'Bradly Hammersmithe',
     'The Other Frox'].each do |name|
      User.new(:name => name).save!
    end

    # a simple view that splits the 'name' field
    # into words and emits one row per word
    DB.save_doc({
      "_id" => "_design/generic",
      :views => {
        :by_word => {
          :map => <<-JS
            function(doc) {
              if (doc.name && doc.name.length > 0) {
                var words = doc.name.split(/\\W/);
                words.forEach(function(word){
                  if (word.length > 0) emit(word, 1);
                });
              }
            }
          JS
        }
      }
    })
  end

  it 'should see all documents' do
    DB.casted_view('generic/by_word')['rows'].size.should == 40
  end

  it 'should work even when no documents match the view params' do
    response = DB.casted_view('generic/by_word',
                              :startkey => 'Zanzibar')
    rows = response['rows']
    rows.class.should == Array
    rows.size.should == 0
  end

  it 'should properly cast documents into CouchRest::Model objects' do
    rows = DB.casted_view('generic/by_word')['rows']
    rows.each do |row|
      row['doc'].class.should == row['doc']['couchrest-type'].constantize
    end
  end

  it "should keep non-CouchRest::Model documents cast as Hashes" do
    DB.save_doc({
      '_id' => 'other-fbenvolio',
      'name' => 'Francis Benvolio'
    })

    rows = DB.casted_view('generic/by_word',
                          :startkey => 'Francis',
                          :endkey => 'Francis')['rows']
    rows.size.should == 1
    doc = rows.first['doc']
    doc['name'].should == 'Francis Benvolio'
    doc['_id'].should == 'other-fbenvolio'
    doc.class.should == Hash
  end

end
