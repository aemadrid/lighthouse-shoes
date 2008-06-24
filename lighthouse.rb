require 'rubygems'
require 'date'
#require 'uri'
#require 'net/http'
require 'xmlsimple'
require 'rio'
require 'yaml'

module Lighthouse
  class Connector
    attr_reader :account, :token, :last_updated, :last_error
    
    def initialize(acc, tkn, default = true) 
      @account, @token = acc, tkn 
      self.class.current = self
    end
      
    def self.current=(v) @current = v end
    def self.current() @current end
    
    def projects(reload = false)
      @projects ||= []
      if @projects.empty? || reload
        @projects.clear
        hash_for(:projects, :project).each do |h| 
          @projects << Project.new_from_hash(h)
        end
        @projects = @projects.sort
        @last_updated = Time.now
      end
      @projects
    rescue => e
      @last_error = e.inspect
      @projects ||= []
    end
    
    def open_projects(reload = false) projects(reload).select{|x| x.open_count > 0} end
    
    def load
      if File.exist?(data_path)
        @last_updated, @projects = YAML::load(rio(data_path).read)
      else
        @last_updated, @projects = nil, []
      end
    end
    
    def save
      projects
      rio(data_path) < [ @last_updated, @projects ].to_yaml
    end
    
    def self.update_yaml(acc, tkn, default = true)
      conn = new(acc, tkn, default)
      conn.projects
      conn.save
    end
    
    def base_url() "http://#{@account}.lighthouseapp.com/" end
    def url_for(action) base_url + "#{action}.xml?_token=#{@token}" end
    #def xml_for(action) Net::HTTP.get_response(URI.parse(url_for(action))).body end
    def xml_for(action) rio(url_for(action)).read end
    def hash_for(action, slice) XmlSimple.xml_in(xml_for(action))[slice.to_s] end
    
    def data_path(app_name = "Lighthouse")
      if RUBY_PLATFORM =~ /win32/
        if ENV['USERPROFILE']
          if File.exist?(File.join(File.expand_path(ENV['USERPROFILE']), "Application Data"))
            user_data_directory = File.join File.expand_path(ENV['USERPROFILE']), "Application Data", app_name
          else
            user_data_directory = File.join File.expand_path(ENV['USERPROFILE']), app_name
          end
        else
          user_data_directory = File.join File.expand_path(Dir.getwd), "data"
        end
      else
        user_data_directory = File.expand_path(File.join("~", ".#{app_name.downcase}"))
      end
      
      unless File.exist?(user_data_directory)
        Dir.mkdir(user_data_directory)
      end
      
      return File.join(user_data_directory, "data.yaml")
    end
  end

  class Project
    include Enumerable
    
    attr_reader :id, :name, :permalink, :description, :description_html, :created_at, :updated_at
    
    def self.new_from_hash(hsh)
      p = new
      p.update_from_hash(hsh)
      p.tickets
      p
    end
    
    def update_from_hash(h)
      @id = h["id"].first["content"].to_i
      @name = h["name"].first
      @permalink = h["permalink"].first
      @description = h["description"].first
      @description_html = h["description-html"].first
      @created_at = Time.parse(h["created-at"].first["content"])
      @updated_at = Time.parse(h["updated-at"].first["content"])
      self
    end
    
    def tickets(reload = false)
      @tickets ||= []
      if @tickets.empty? || reload
        @tickets.clear
        Connector.current.hash_for("projects/#{@id}/tickets", :ticket).each do |h| 
          h["project_id"] = @id
          @tickets << Ticket.new_from_hash(h)
        end rescue nil
        @tickets = @tickets.sort
      end
      @tickets
    end
    
    def open_tickets(reload = false) tickets(reload).select{|x| %w{new open}.include? x.state} end
    def open_count(reload = false) open_tickets(reload).size end
    
    def url() Connector.current.base_url + "projects/#{@id}-#{@permalink}/tickets/" end
    def sortable_base() name end
    def <=>(other) sortable_base <=> other.sortable_base end
  end
  
  class Ticket
    include Enumerable
    
    attr_reader :project_id, :number, :title, :permalink, :state, :closed, :created_at, :updated_at

    def self.new_from_hash(hsh)
      new.update_from_hash(hsh)
    end
    
    def update_from_hash(h)
      @project_id = h["project_id"]
      @number = h["number"].first["content"].to_i
      @title = h["title"].first
      @permalink = h["permalink"].first
      @state = h["state"].first
      @closed = h["number"].first["content"] == true
      @created_at = Time.parse(h["created-at"].first["content"])
      @updated_at = Time.parse(h["updated-at"].first["content"])
      self
    end
    
    def url() Connector.current.base_url + "projects/#{@project_id}/tickets/#{@number}-#{@permalink}" end
    def state_level() case state; when "new":0; when "resolved":9; else 5; end; end
    def sortable_base() "#{10 - state_level}-#{updated_at}" end
    def <=>(other) other.sortable_base <=> sortable_base end
    def fresh?(minutes = 15) (Time.now - @updated_at) < (minutes * 60) end
  end
end
