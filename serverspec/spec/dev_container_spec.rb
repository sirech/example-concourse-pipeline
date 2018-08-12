require_relative 'spec_helper'

describe 'dev-container' do
  describe 'node' do
    describe file('/usr/local/bin/node') do
      it { is_expected.to be_executable }
    end

    [
      [:node, /10.4.1/],
      [:npm, /6.1.0/]
    ].each do |executable, version|
      describe command("#{executable} -v") do
        its(:stdout) { is_expected.to match(version) }
      end
    end

    describe command('npm doctor') do
      its(:exit_status) { is_expected.to eq 0 }
    end
  end

  describe 'shell' do
    %i[shellcheck].each do |executable|
      describe file("/usr/bin/#{executable}") do
        it { is_expected.to be_executable }
      end
    end
  end
end
