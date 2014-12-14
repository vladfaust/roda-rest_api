class Roda
	module RodaPlugins

		module HeaderMatchers
			module RequestMethods

				private

				def match_subdomain(subdomain)
					host.match /^#{subdomain}\./
				end
			end
		end

		module RestApi

			def self.load_dependencies(app, _opts = {})
				app.plugin :all_verbs
				app.plugin :symbol_matchers
				app.plugin :header_matchers
			end
			
			class Resource
				
				APPLICATION_JSON = 'application/json'.freeze

				attr_reader :singleton, :primary_key, :content_type
				
				def initialize(request, options={})
					@request = request
					@singleton = options.delete(:singleton) || false
					@primary_key = options.delete(:primary_key) || "id"
					@content_type = options.delete(:content_type) || APPLICATION_JSON
				end
				
				def list(&block)
					@list = block if block
					@list || ->(_){raise NotImplementedError, "list"}
				end
				
				def one(&block)
					@one = block if block
					@one || ->(_){raise NotImplementedError, "one"}
				end
				
				def save(&block)
					@save = block if block
					@save || ->(_){raise NotImplementedError, "save"}
				end
				
				def delete(&block)
					@delete = block if block
					@delete || ->(_){raise NotImplementedError, "delete"}
				end
				
				def serialize(&block)
					@serialize = block if block
					@serialize || ->(obj){obj.is_a?(String) ? obj : obj.send(:to_json)}
				end
				
				def routes(*routes)
					@routes = routes
				end
										
				def routes!
					@routes = %i{ index show create update destroy edit new } unless @routes
					@routes.delete :index if @singleton
					@routes.each { |route| @request.send(route) }
				end
				
				def perform(method, id = nil)
					args = method === :save ? JSON.parse(@request.body) : @request.GET
					args.merge!(@primary_key => id) if id
					self.send(method).call(args) rescue @request.response.status = 404
				end

			end

			module RequestMethods

				def api(options={}, &block)
					api_path = options.delete(:path) || 'api'
					on([api_path, true], options, &block)
				end

				def version(version, &block)
			  		on("v#{version}", &block)
			  end

			  def resource(name, options={})
					@resource = Resource.new(self, options)
			  		on(name.to_s, options) do
				  		yield @resource
				  		@resource.routes!
				  		response.status = 404
				  	end
			  end

			  def index(options={}, &block)
				  block ||= ->{ @resource.perform(:list) }
					get(['', true], options, &block)
			  end

			  def show(options={}, &block)
				  path, block = path_and_block(:one, nil, &block)
				  	get(path, options, &block)
			  end

			  def create(options={}, &block)
				  block ||= ->{@resource.perform(:save)}
			  		post(["", true], options, &block)
			  end

			  def update(options={}, &block)
				  path, block = path_and_block(:save, nil, &block)
				  options.merge!(method: [:put, :patch])
			  		is(path, options, &block)
			  end

			  def destroy(options={}, &block)
				  path, block = path_and_block(:delete, nil, &block)
			  		delete(path, options) do
						response.status = 204
				  		yield if block_given?
				  	end
			  end

			  def edit(options={}, &block)
				  path, block = path_and_block(:one, "edit", &block)
			  		get(path, options, &block)
			  end

			  def new(options={}, &block)
				  block ||= ->{@resource.perform(:one, "new")}
			  		get("new", options, &block)
			  end
			  			  
			  private
			  
			  def path_and_block(method, path = nil, &block)
				  if @resource.singleton
					  block ||= ->(){@resource.perform(method)}
					  path = ["", true] unless path
					else
						block ||= ->(id){@resource.perform(method, id)}
						path = [":d", path].compact.join("/")
					end
					[path, block]
				end
			  
			  CONTENT_TYPE = 'Content-Type'.freeze

			  def block_result_body(result)
				  if result && @resource
				  		response[CONTENT_TYPE] = @resource.content_type
				  		@resource.serialize.call(result)
				  	else
					  	super
					end
			  end
			  

			end

		end

		register_plugin(:rest_api, RestApi)

	end
end