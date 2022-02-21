# gwms-dev-setup
Setup tools to deploy GlideinWMS for development

### Installing a factory
<pre>
install_factory.sh --frontend fermicloud406.fnal.gov --factoryrepo osg-development --osgrepo osg-upcoming
</pre>

### Installing a frontend
<pre>
install_frontend.sh --factory fermicloud442.fnal.gov --frontendrepo osg-development --osgrepo osg-upcoming [--cert PATH_TO_CERT --key PATH_TO_KEY]
</pre>
