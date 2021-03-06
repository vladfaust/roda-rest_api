require "test_helpers"

class RestApiSplitRoutesTest < Minitest::Test
	include TestHelpers
	
	

	def setup
		app :rest_api do |r|
			def anything
				nil
			end

			r.resource :things do |u|
				u.one { |params| "one" }
				u.list { |params| "list" }
				u.routes :show
				u.routes :index  do
				 	anything
 				end
			end
		end
	end
	
	def test_split_routes
		assert_equal "one", request.get("/things/1").body
		assert_equal "list", request.get("/things").body
	end
		
end
