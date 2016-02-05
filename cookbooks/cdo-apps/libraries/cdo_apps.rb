module CdoApps
  def setup_app(app_name)
    user = node[:user]
    home = node[:home]
    root = File.join home, node.chef_environment
    app_root = File.join root, app_name
    init_script = "/etc/init.d/#{app_name}"

    template init_script do
      source 'init.d.erb'
      user 'root'
      group 'root'
      mode '0755'
      variables src_file: "#{app_root}/config/unicorn.rb",
        app_root: app_root,
        pid_file: "#{app_root}/config/unicorn.rb.pid",
        user: user,
        env: node.chef_environment
      notifies :restart, "service[#{app_name}]", :delayed
    end

    log_dir = File.join app_root, 'log'
    directory log_dir do
      recursive true
      user user
      group user
    end

    template "/etc/logrotate.d/#{app_name}" do
      source 'logrotate.erb'
      user 'root'
      group 'root'
      mode '0644'
      variables app_name: app_name,
        log_dir: log_dir
    end

    if node['cdo-newrelic']
      template "#{app_root}/config/newrelic.yml" do
        source 'newrelic.yml.erb'
        user user
        group user
        variables app_name: app_name.capitalize,
          log_dir: log_dir,
          auto_instrument: false
      end
    end

    utf8 = 'en_US.UTF-8'
    env = {
      'LC_ALL' => utf8,
      'LANGUAGE' => utf8,
      'LANG' => utf8,
      'RAILS_ENV' => node.chef_environment
    }
    execute "setup-#{app_name}" do
      command "bundle exec rake #{app_name}:setup_db"
      cwd app_root
      environment env.merge(node['cdo-apps']['bundle_env'])
      user user
      group user
      action :nothing
      notifies :run, "execute[build-#{app_name}]", :immediately
    end

    execute "build-#{app_name}" do
      command "bundle exec rake build:#{app_name}"
      cwd root
      environment env.merge(node['cdo-apps']['bundle_env'])
      user user
      group user
      action :nothing
    end

    # Builds the app.
    setup_cmd = "execute[#{node['cdo-apps']['local_mysql'] ? "setup-#{app_name}" : "build-#{app_name}"}]"
    ruby_block "build-#{app_name}" do
      block {}
      notifies :run, setup_cmd, :immediately
    end

    service app_name do
      supports reload: true
      reload_command "#{init_script} upgrade"
      action [:enable, :start]

      # Restart when Ruby is upgraded
      subscribes :restart, "apt_package[ruby#{node['cdo-ruby']['version']}]", :delayed if node['cdo-ruby']

      # Restart when gem bundle is updated
      subscribes :restart, 'execute[bundle-install]', :delayed
      only_if { File.exist? init_script }
    end

  end
end
