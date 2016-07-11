class Api::LiveController < ApplicationController
	before_action :authenticate_user!, :except => [:index, :onair, :basic_data, :live, :schedule, :update_stream]
	
	skip_before_filter :verify_authenticity_token
  before_filter :cors_preflight_check
  after_filter :cors_set_access_control_headers

  def schedule
  	streams = Stream.all.select("name, chennal as channel, live_time_id as time_id")
  									.order("time_id")

  	render :json => streams
  end

  def update_stream
  	data = params[:postData]

  	# delete all data
  	Stream.all.each do |stream|
  		stream.destroy
  	end

  	Stream.connection.execute('ALTER TABLE `streams` AUTO_INCREMENT = 1;')

  	data.each_value do |item|
  		stream = Stream.new

  		stream.name = item['name'] if item['name']
  		stream.chennal = item['channel']
  		stream.live_time = LiveTime.find(item['time_id'].to_i)
  		stream.live = Live.find_by_name(stream.name)

  		stream.save
  	end

  	render :json => { status: "success" }
  end

	# def admin
	# 	sort_by = params[:sort_by]

	# 	case sort_by
	# 	when "school"
	# 		sort_by = "live_schools.name"
	# 	when "department"
	# 		sort_by = "live_departments.name"
	# 	when "time"
	# 		sort_by = "live_times.start"
	# 	end

	# 	@lives = Live.joins(:live_department, :live_school)
	# 						   .select("lives.id, lives.title,
	# 						   					live_departments.name as department,
	# 						   					live_schools.name as school")
	# 						   .order(sort_by)

	# 	respond_to do |format|
	# 		format.json { render json: @lives.to_json(include: [:live_times]) }
	# 	end
	# end

	def index
		lives = Live.joins(:live_department, :live_school, :live_times)
							   .select("lives.id as user_id, lives.title,
							   					live_departments.name as department,
							   					live_schools.name as school,
							   					live_times.id as time_id,
							   					live_times.start as start,
							   					live_times.end as end")

		data = []

		lives.each do |live|
			data_item = {}

			data_item[:title] = live.title
			data_item[:school] = /[\S]+$/.match(live.school)[0]
			data_item[:department] = /[\S]+$/.match(live.department)[0]
			data_item[:start] = live.start
			data_item[:end] = live.end
			data_item[:user_id] = live.user_id
			data_item[:time_id] = live.time_id

			data.push data_item
		end

		respond_to do |format|
			format.json { render json: data }
		end
	end

	# test if it is on air, if true return youtube_url
	def onair
		ioh_url = params[:ioh_url]

		# test onair
		onair = false

		if ioh_url
			live = Live.find_by_ioh_url(URI.escape(ioh_url))

			onair = live.onair
		end

		if live
			render json: { onair: onair, url: live.youtube_url, banner: live.banner_link }
		else
			render json: { onair: onair, message: "error!!" }
		end
	end

	def live

		order = params[:order]
		data = []

		if order == "time"
			lives = Live.joins(:live_department, :live_school, :live_times)
							    .select("lives.name, lives.ioh_url, lives.onair,
							   					 live_departments.name as department,
							   					 live_schools.name as school,
							   					 live_times.start as start,
							   					 live_times.end as end")
							    .order("start, school")
		elsif order == "school"
			lives = Live.joins(:live_department, :live_school, :live_times)
							    .select("lives.name, lives.ioh_url, lives.onair,
							   					 live_departments.name as department,
							   					 live_schools.name as school,
							   					 live_times.start as start,
							   					 live_times.end as end")
							    .order("school, start")
		elsif order == "major_one"
			lives = Live.joins(:live_department, :live_school, :live_times)
									.where("live_departments.group = 1")
								  .select("lives.name, lives.ioh_url, lives.onair,
							   					 live_departments.name as department,
							   					 live_schools.name as school,
							   					 live_times.start as start,
							   					 live_times.end as end")
								  .order("department, start")
		elsif order == "major_two"
			lives = Live.joins(:live_department, :live_school, :live_times)
									.where("live_departments.group = 2")
								  .select("lives.name, lives.ioh_url, lives.onair,
							   					 live_departments.name as department,
							   					 live_schools.name as school,
							   					 live_times.start as start,
							   					 live_times.end as end")
								  .order("department, start")
		end  	

		lives.each do |live|
			data_item = {}

			data_item[:name] = live.name
			data_item[:school] = /[\S]+$/.match(live.school)[0]
			data_item[:department] = /[\S]+$/.match(live.department)[0]
			data_item[:start] = live.start
			data_item[:link] = live.ioh_url

			if live.onair && live.start.today?
				data_item[:onair] = "onair"
			elsif Time.now > live.end
				data_item[:onair] = "end"
			elsif Time.now < live.end
				data_item[:onair] = "yet"
			end

			data.push data_item
		end

		respond_to do |format|
			format.json { render json: data }
		end
	end

	def basic_data
		data = { school: [], department_one: [], department_two: [], time: [] }

		# get school		
		lives = Live.all.select(:live_school_id).includes(:live_school)

		lives.each do |live|
			data[:school].push /[\S]+$/.match(live.live_school.name)[0]
		end

		data[:school].uniq!

		#get department 1
		lives = Live.all.select(:live_department_id).includes(:live_department)
		
		lives.each do |live|
			if live.live_department.group == 1
				data[:department_one].push /[\S]+$/.match(live.live_department.name)[0]
			end
		end

		data[:department_one].uniq!

		#get department 2
		lives = Live.all.select(:live_department_id).includes(:live_department)
		
		lives.each do |live|
			if live.live_department.group != 1
				data[:department_two].push /[\S]+$/.match(live.live_department.name)[0]
			end
		end

		data[:department_two].uniq!

		#get time
		times = LiveTime.all.select("start, end").order(:start)

		times.each do |time|
			item = {}

			item[:time] = time.start
			item[:over] = Time.now > time.end
			data[:time].push item
		end

		respond_to do |format|
			format.json { render json: data }
		end
	end

	def test
		@lives = Talk.all

		respond_to do |format|
			format.json { render json: @lives.to_json }
		end
	end

	def update_talk
		talk = params[:talk]

		if talk
			@talk = Talk.new
			@talk.title = talk[:title]
			@talk.post_name = talk[:name]
			@talk.live_school = LiveSchool.find talk[:school] unless talk[:school] == "NULL"
			@talk.live_department = LiveDepartment.find talk[:department]

			@talk.save
		end

		render plain: "good"
	end

	def update_school
		school = params[:school]

		if school
			@school = LiveSchool.new
			@school.name = school[:name]

			@school.save
		end

		render plain: "good"
	end

	def update_department
		department = params[:department]

		if department
			@department = LiveDepartment.new
			@department.name = department[:name]

			@department.save
		end

		render plain: "good"
	end

	private
	# For all responses in this controller, return the CORS access control headers.
  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, PATCH'
    headers['Access-Control-Max-Age'] = "1728000"
  end

  # If this is a preflight OPTIONS request, then short-circuit the
  # request, return only the necessary headers and return an empty
  # text/plain.

  def cors_preflight_check
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = 'GET, PATCH'
    headers['Access-Control-Allow-Headers'] = 'X-Requested-With, X-Prototype-Version'
    headers['Access-Control-Max-Age'] = '1728000'
  end
end
