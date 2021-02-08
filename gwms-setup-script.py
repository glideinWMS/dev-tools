#!/usr/bin/python


# Before running XML functions
# sed 's|<vo>|TO_REPLACE_VO|g' /etc/gwms-frontend/frontend.xml | sed 's|<username>|TO_REPLACE_USERNAME|g' > frontend.xml.sed
# cp  /etc/gwms-frontend/frontend.xml  /etc/gwms-frontend/frontend.xml.orig; mv -f frontend.xml.sed /etc/gwms-frontend/frontend.xml

# After running this
# mv -f /etc/gwms-frontend/frontend.xml.new /etc/gwms-frontend/frontend.xml
# mv -f /etc/gwms-factory/glideinWMS.xml.new /etc/gwms-factory/glideinWMS.xml
# mv -f /etc/condor/certs/condor_mapfile1 /etc/condor/certs/condor_mapfile
# chown frontend: /etc/gwms-frontend/frontend.xml*
# chown gfactory: /etc/gwms-factory/glideinWMS.xml*


import sys
import os
import subprocess
from string import Template as T
#from xml.etree.ElementTree import ElementTree as ET
import xml.etree.ElementTree as ET

FACTORY='fermicloud110.fnal.gov'
FRONTEND='fermicloud048.fnal.gov'
XML_LOG_ALL='<process_log backup_count="5" extension="all" max_days="7.0" max_mbytes="100.0" min_days="3.0" msg_types="INFO,DEBUG,ERR,WARN,EXCEPTION"/>'
XML_LOG_BAD='<process_log backup_count="5" extension="bad" max_days="7.0" max_mbytes="100.0" min_days="3.0" msg_types="ERR,WARN,EXCEPTION"/>'

XML_COLLECTOR1='<collector DN="/DC=com/DC=DigiCert-Grid/O=Open Science Grid/OU=Services/CN=${factory}" comment="Define factory collector globally for simplicity" factory_identity="gfactory@${factory}" my_identity="vofrontend_service@${factory}" node="${factory}"/>'
XML_COLLECTOR2='<collector DN="/DC=org/DC=opensciencegrid/O=Open Science Grid/OU=Services/CN=${factory}" comment="Define factory collector globally for simplicity" factory_identity="gfactory@${factory}" my_identity="vofrontend_service@${factory}" node="${factory}"/>'
XML_COLLECTOR3='<collector DN="/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${factory}" comment="Define factory collector globally for simplicity" factory_identity="gfactory@${factory}" my_identity="vofrontend_service@${factory}" node="${factory}"/>'

XML_SECURITY1='''    <security classad_proxy="/etc/gwms-frontend/fe_proxy" proxy_DN="/DC=com/DC=DigiCert-Grid/O=Open Science Grid/OU=Services/CN=${frontend}" proxy_selection_plugin="ProxyAll" security_name="vofrontend_service" sym_key="aes_256_cbc">
      <credentials>
         <credential absfname="/etc/gwms-frontend/mm_proxy" security_class="frontend" trust_domain="grid" type="grid_proxy"/>
      </credentials>
   </security>
'''
XML_SECURITY2='''    <security classad_proxy="/etc/gwms-frontend/fe_proxy" proxy_DN="/DC=org/DC=opensciencegrid/O=Open Science Grid/OU=Services/CN=${frontend}" proxy_selection_plugin="ProxyAll" security_name="vofrontend_service" sym_key="aes_256_cbc">
      <credentials>
         <credential absfname="/etc/gwms-frontend/mm_proxy" security_class="frontend" trust_domain="grid" type="grid_proxy"/>
      </credentials>
   </security>
'''
XML_SECURITY3='''    <security classad_proxy="/etc/gwms-frontend/fe_proxy" proxy_DN="/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${frontend}" proxy_selection_plugin="ProxyAll" security_name="vofrontend_service" sym_key="aes_256_cbc">
      <credentials>
         <credential absfname="/etc/gwms-frontend/mm_proxy" security_class="frontend" trust_domain="grid" type="grid_proxy"/>
      </credentials>
   </security>
'''

XML_WMS_COLLECTOR1='''   <collectors>
      <collector DN="/DC=com/DC=DigiCert-Grid/O=Open Science Grid/OU=Services/CN=${frontend}" group="default" node="${frontend}:9618" secondary="False"/>
      <collector DN="/DC=com/DC=DigiCert-Grid/O=Open Science Grid/OU=Services//CN=${frontend}" group="default" node="${frontend}:9620-9660" secondary="True"/>
   </collectors>
'''
XML_WMS_COLLECTOR2='''   <collectors>
      <collector DN="/DC=org/DC=opensciencegrid/O=Open Science Grid/OU=Services/CN=${frontend}" group="default" node="${frontend}:9618" secondary="False"/>
      <collector DN="/DC=org/DC=opensciencegrid/O=Open Science Grid/OU=Services/CN=${frontend}" group="default" node="${frontend}:9620-9660" secondary="True"/>
   </collectors>
'''
#/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=fermicloud315.fnal.gov
XML_WMS_COLLECTOR3='''   <collectors>
      <collector DN="/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${frontend}" group="default" node="${frontend}:9618" secondary="False"/>
      <collector DN="/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${frontend}" group="default" node="${frontend}:9620-9660" secondary="True"/>
   </collectors>
'''


XML_SCHEDD1='            <schedd DN="/DC=com/DC=DigiCert-Grid/O=Open Science Grid/OU=Services/CN=${frontend}" fullname="${frontend}"/>'
XML_SCHEDD2='            <schedd DN="/DC=org/DC=opensciencegrid/O=Open Science Grid/OU=Services/CN=${frontend}" fullname="${frontend}"/>'
XML_SCHEDD3='            <schedd DN="/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${frontend}" fullname="${frontend}"/>'


def is_osg_certificate(certfname="/etc/grid-security/hostcert.pem"):
    try:
        p = subprocess.Popen("openssl x509 -noout -subject -in %s" % certfname, shell=True, 
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        s1, s2 = p.communicate()
        subj = s1[9:].strip()
        return "DC=opensciencegrid" in subj
    except:
        print "Error evaluating host certificate: %s" % s2
        print "Considering DigiCert certificates"
    return False

def is_incommon_certificate(certfname="/etc/grid-security/hostcert.pem"):
    try:
        p = subprocess.Popen("openssl x509 -noout -subject -in %s" % certfname, shell=True, 
                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        s1, s2 = p.communicate()
        subj = s1[9:].strip()
        return "DC=incommon" in subj
    except:
        print "Error evaluating host certificate: %s" % s2
        print "Considering DigiCert certificates"
    return False

HTC_TARBALLS = """   <condor_tarballs>
      <condor_tarball arch="default" base_dir="/usr" os="default" version="default"/>
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.9.7-x86_64_CentOS7-unstripped" os="rhel7" version="8.9"/>
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.9.7-x86_64_CentOS8-unstripped" os="rhel8" version="8.9"/> 
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.8.9-x86_64_CentOS7-stripped" os="rhel7" version="default"/>
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.8.9-x86_64_CentOS8-stripped" os="rhel8" version="default"/> 
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.8.9-x86_64_RedHat6-stripped" os="rhel6" version="default"/> 
  </condor_tarballs>
"""

# to add back for RHEL6 nodes
"""
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.4.0-x86_64_RedHat7-stripped" os="rhel7" version="8.4.0"/>
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.4.0-x86_64_RedHat6-stripped" os="rhel6" version="8.4.0"/> 
      <condor_tarball arch="x86" base_dir="/var/lib/gwms-factory/condor/condor-8.4.0-x86_RedHat6-stripped" os="rhel6" version="default"/> 
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.2.6-x86_64_RedHat5-stripped" os="rhel5" version="8.2.6"/>
      <condor_tarball arch="default" base_dir="/var/lib/gwms-factory/condor/condor-8.2.6-x86_64_RedHat6-stripped" os="rhel6" version="8.2.6"/> 
 """

def factory_config1(fname='/etc/gwms-factory/glideinWMS.xml', entries=['ITB_FC_CE2', 'ITB_FC_CE3']):
    """Reconfig the factory

    :type fname: :obj:`str`
    :arg fname: Frontend configuration file (Default: '/etc/gwms-factory/glideinWMS.xml')

    """
    tree = ET.ElementTree()
    tree.parse(fname)
    # process_logs
    elem = tree.find('log_retention/process_logs')
    elem.append(ET.XML(XML_LOG_ALL))
    elem.append(ET.XML(XML_LOG_BAD))
    elem = tree.find('condor_tarballs')
    tree.getroot().remove(elem)
    tree.getroot().append(ET.XML(HTC_TARBALLS))
    elem = tree.find('entries')
    for i in entries:
        elem.append(ET.XML(ENTRIES[i]))
    # open("%s.new" % fname, 'w') 
    tree.write("%s.new" % fname)

  
def factory_add(entry, fname='/etc/gwms-factory/glideinWMS.xml'):
    tree = ET.ElementTree()
    tree.parse(fname)
    elem = tree.find('entries')
    # to avoid duplicates w/ same name
    for i in list(elem.getchildren()):
        if i.get('name')==entry:
            print "Entry %s already there. Removing it." % entry
            elem.remove(i)
    print "Adding entry (to %s.new): %s" % (fname, entry)
    elem.append(ET.XML(ENTRIES[entry]))
    tree.write("%s.new" % fname)
    

def factory_remove(entry, fname='/etc/gwms-factory/glideinWMS.xml'):
    tree = ET.ElementTree()
    tree.parse(fname)
    elem = tree.find('entries')
    not_found = True
    for i in list(elem.getchildren()):
        if i.get('name')==entry:
            print "Removing entry: %s" % entry
            not_found = False
            elem.remove(i)
    if not_found:
        print "Entry %s not found" % entry
    else:
        print "The new content is in: %s" % fname
        tree.write("%s.new" % fname)


def factory_list(fname='/etc/gwms-factory/glideinWMS.xml'):
    print "All available entries: %s" % ENTRIES.keys()
    tree = ET.ElementTree()
    tree.parse(fname)
    e_list = []
    elem = tree.find('entries')
    for i in elem.getchildren():
        e_list.append(i.get('name'))
    print "Entries in Factory: %s" % e_list


def frontend_config1(fname='/etc/gwms-frontend/frontend.xml'):
    """Reconfig the frontend

    :type fname: :obj:`str`
    :arg fname: Frontend configuration file (Default: '/etc/gwms-frontend/frontend.xml')

    """
    # select certificates DN (DigiCert/OSG)
    XML_COLLECTOR = XML_COLLECTOR1
    XML_SECURITY = XML_SECURITY1
    XML_WMS_COLLECTOR = XML_WMS_COLLECTOR1
    XML_SCHEDD = XML_SCHEDD1
    if is_osg_certificate():
        XML_COLLECTOR = XML_COLLECTOR2
        XML_SECURITY = XML_SECURITY2
        XML_WMS_COLLECTOR = XML_WMS_COLLECTOR2
        XML_SCHEDD = XML_SCHEDD2
    elif is_incommon_certificate():
        XML_COLLECTOR = XML_COLLECTOR3
        XML_SECURITY = XML_SECURITY3
        XML_WMS_COLLECTOR = XML_WMS_COLLECTOR3
        XML_SCHEDD = XML_SCHEDD3
    tree = ET.ElementTree()
    tree.parse(fname)
    # process_logs
    elem = tree.find('log_retention/process_logs')
    elem.append(ET.XML(XML_LOG_ALL))
    elem.append(ET.XML(XML_LOG_BAD))
    # factory
    elem = tree.find('match/factory')
    elem.set('query_expr', 'True')
    # collector   
    collectors = tree.find('match/factory/collectors')
    for elem in list(collectors.getchildren()):
        collectors.remove(elem)
    new_coll = T(XML_COLLECTOR).substitute(dict(factory=FACTORY))
    collectors.append(ET.XML(new_coll))
    # security
    elem = tree.find('security')
    tree.getroot().remove(elem)
    elem = T(XML_SECURITY).substitute(dict(frontend=FRONTEND))    
    tree.getroot().append(ET.XML(elem))
    # schedd
    schedds = tree.find('match/job/schedds')
    for elem in list(schedds.getchildren()):
        schedds.remove(elem)
    new_schedd = T(XML_SCHEDD).substitute(dict(frontend=FRONTEND))
    schedds.append(ET.XML(new_schedd))
    # WMS collector
    elem = tree.find('collectors')
    tree.getroot().remove(elem)
    elem = T(XML_WMS_COLLECTOR).substitute(dict(frontend=FRONTEND))    
    tree.getroot().append(ET.XML(elem))     
    # open("%s.new" % fname, 'w') 
    tree.write("%s.new" % fname)


# Assumption that factory and frontend have the same type of certificate (digicert/osg)

# To submit to HTCondor-CEs the certificates need to be recognized, https://ticket.grid.iu.edu/32342
# Lines to authenticate hosts that are part of the OSG, RDIG, ANSP, Terena, and CERN via certificate (copying them below):
HTCE_DNs='''GSI "^\/DC\=com\/DC\=DigiCert-Grid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=DigiCert-Grid\/DC\=com\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=opensciencegrid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=RU\/O\=RDIG\/OU\=hosts\/OU=*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=BR\/O\=ANSP\/OU\=ANSPGrid\ CA\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=terena\/DC\=tcs.*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=ch\/DC\=cern\/OU\=computers\/CN\=(host\/)?([A-Za-z0-9.\-]*)$" \\2@cern.ch
'''

# old personal cert GSI "^\/DC\=com\/DC\=DigiCert\-Grid\/O\=Open\ Science\ Grid\/OU\=People\/CN\=Marco\ Mambelli$$" vofrontend_service
# Fermilab cert GSI "^/DC=org/DC=cilogon/C=US/O=Fermi National Accelerator Laboratory/OU=People/CN=Marco Mambelli/CN=UID:marcom" vofrontend_service 
HTC_CERTMAP1 = '''GSI "^\/DC\=com\/DC\=DigiCert\-Grid\/O\=Open\ Science\ Grid\/OU\=Services\/CN\=${frontend}$$" vofrontend_service
GSI "^\/DC\=com\/DC\=DigiCert\-Grid\/O\=Open\ Science\ Grid\/OU\=Services\/CN\=${factory}$$" gfactory
GSI "^/DC=org/DC=cilogon/C=US/O=Fermi National Accelerator Laboratory/OU=People/CN=Marco Mambelli/CN=UID:marcom" vofrontend_service 
GSI "^\/DC\=org\/DC\=opensciencegrid\/O\=Open\ Science\ Grid\/OU\=People\/CN\=Marco\ Mambelli\ 247$$" vofrontend_service
GSI "^\/DC\=org\/DC\=incommon\/C\=US\/ST\=IL\/L\=Batavia\/O\=Fermi\ Research\ Alliance\/OU\=Fermilab\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=com\/DC\=DigiCert-Grid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=DigiCert-Grid\/DC\=com\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=opensciencegrid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=RU\/O\=RDIG\/OU\=hosts\/OU=*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=BR\/O\=ANSP\/OU\=ANSPGrid\ CA\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=terena\/DC\=tcs.*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=ch\/DC\=cern\/OU\=computers\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@cern.ch
GSI (.*) anonymous
FS (.*) \\1
'''
HTC_CERTMAP2 = '''GSI "^\/DC\=org\/DC\=opensciencegrid\/O\=Open\ Science\ Grid\/OU\=Services\/CN\=${frontend}$$" vofrontend_service
GSI "^\/DC\=org\/DC\=opensciencegrid\/O\=Open\ Science\ Grid\/OU\=Services\/CN\=${factory}$$" gfactory
GSI "^/DC=org/DC=cilogon/C=US/O=Fermi National Accelerator Laboratory/OU=People/CN=Marco Mambelli/CN=UID:marcom" vofrontend_service 
GSI "^\/DC\=org\/DC\=opensciencegrid\/O\=Open\ Science\ Grid\/OU\=People\/CN\=Marco\ Mambelli\ 247$$" vofrontend_service
GSI "^\/DC\=org\/DC\=incommon\/C\=US\/ST\=IL\/L\=Batavia\/O\=Fermi\ Research\ Alliance\/OU\=Fermilab\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=incommon\/C\=US\/ST\=Illinois\/L\=Batavia\/O\=Fermi\ Research\ Alliance\/OU\=Fermilab\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=com\/DC\=DigiCert-Grid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=DigiCert-Grid\/DC\=com\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=opensciencegrid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=RU\/O\=RDIG\/OU\=hosts\/OU=*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=BR\/O\=ANSP\/OU\=ANSPGrid\ CA\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=terena\/DC\=tcs.*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=ch\/DC\=cern\/OU\=computers\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@cern.ch
GSI (.*) anonymous
FS (.*) \\1
'''
HTC_CERTMAP3 = '''GSI "^/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${frontend}$$" vofrontend_service
GSI "^/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${factory}$$" gfactory
GSI "^/DC=org/DC=cilogon/C=US/O=Fermi National Accelerator Laboratory/OU=People/CN=Marco Mambelli/CN=UID:marcom" vofrontend_service 
GSI "^\/DC\=org\/DC\=opensciencegrid\/O\=Open\ Science\ Grid\/OU\=People\/CN\=Marco\ Mambelli\ 247$$" vofrontend_service
GSI "^\/DC\=org\/DC\=incommon\/C\=US\/ST\=Illinois\/L\=Batavia\/O\=Fermi\ Research\ Alliance\/OU\=Fermilab\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=incommon\/C\=US\/ST\=IL\/L\=Batavia\/O\=Fermi\ Research\ Alliance\/OU\=Fermilab\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@old.daemon.opensciencegrid.org
GSI "^\/DC\=com\/DC\=DigiCert-Grid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=DigiCert-Grid\/DC\=com\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=opensciencegrid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=RU\/O\=RDIG\/OU\=hosts\/OU=*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=BR\/O\=ANSP\/OU\=ANSPGrid\ CA\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=terena\/DC\=tcs.*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=ch\/DC\=cern\/OU\=computers\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@cern.ch
GSI (.*) anonymous
FS (.*) \\1
'''
HTC_CERTMAP_ALL = '''GSI "^\/DC\=com\/DC\=DigiCert\-Grid\/O\=Open\ Science\ Grid\/OU\=Services\/CN\=${frontend}$$" vofrontend_service
GSI "^\/DC\=org\/DC\=opensciencegrid\/O\=Open\ Science\ Grid\/OU\=Services\/CN\=${frontend}$$" vofrontend_service
GSI "^/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${frontend}$$" vofrontend_service
GSI "^\/DC\=com\/DC\=DigiCert\-Grid\/O\=Open\ Science\ Grid\/OU\=Services\/CN\=${factory}$$" gfactory
GSI "^\/DC\=org\/DC\=opensciencegrid\/O\=Open\ Science\ Grid\/OU\=Services\/CN\=${factory}$$" gfactory
GSI "^/DC=org/DC=incommon/C=US/ST=Illinois/L=Batavia/O=Fermi Research Alliance/OU=Fermilab/CN=${factory}$$" gfactory
GSI "^/DC=org/DC=cilogon/C=US/O=Fermi National Accelerator Laboratory/OU=People/CN=Marco Mambelli/CN=UID:marcom" vofrontend_service 
GSI "^\/DC\=org\/DC\=opensciencegrid\/O\=Open\ Science\ Grid\/OU\=People\/CN\=Marco\ Mambelli\ 247$$" vofrontend_service
GSI "^\/DC\=org\/DC\=incommon\/C\=US\/ST\=Illinois\/L\=Batavia\/O\=Fermi\ Research\ Alliance\/OU\=Fermilab\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=incommon\/C\=US\/ST\=IL\/L\=Batavia\/O\=Fermi\ Research\ Alliance\/OU\=Fermilab\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@old.daemon.opensciencegrid.org
GSI "^\/DC\=com\/DC\=DigiCert-Grid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=DigiCert-Grid\/DC\=com\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=opensciencegrid\/O=Open Science Grid\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=RU\/O\=RDIG\/OU\=hosts\/OU=*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/C\=BR\/O\=ANSP\/OU\=ANSPGrid\ CA\/OU\=Services\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=org\/DC\=terena\/DC\=tcs.*\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@daemon.opensciencegrid.org
GSI "^\/DC\=ch\/DC\=cern\/OU\=computers\/CN\=(host\/)?([A-Za-z0-9.\-]*)$$" \\2@cern.ch
GSI (.*) anonymous
FS (.*) \\1
'''

def escape(instr):
    return instr.replace('.', '\.')

def write_htc_map(fname='/etc/condor/certs/condor_mapfile1'):
    f = open(fname, 'w')
    HTC_CERTMAP = HTC_CERTMAP1
    if is_osg_certificate():
        HTC_CERTMAP = HTC_CERTMAP2
    elif is_incommon_certificate():
        HTC_CERTMAP = HTC_CERTMAP3
    f.write(T(HTC_CERTMAP).substitute(dict(frontend=escape(FRONTEND), factory=escape(FACTORY))))
    f.close()


ENTRIES = {'old_ITB_FC_CE2': """      <entry name="ITB_FC_CE2" auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud025.fnal.gov/jobmanager-condor" gridtype="gt2" rsl="(queue=default)(jobtype=single)" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100"/>
               <per_entry glideins="10000" held="1000" idle="2000"/>
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2"/>
            <remove max_per_cycle="5" sleep="0.2"/>
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False"/>
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="fixed">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr name="CONDOR_ARCH" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="default"/>
            <attr name="CONDOR_OS" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="rhel6"/>
            <attr name="GLEXEC_JOB" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="False"/>
            <attr name="GLIDEIN_Site" const="True" glidein_publish="True" job_publish="True" parameter="True" publish="True" type="string" value="ITB_FC_CE2"/>
            <attr name="USE_CCB" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="string" value="True"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
'ITB_FC_CE2': """      <entry name="ITB_FC_CE2" auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud025.fnal.gov fermicloud025.fnal.gov:9619" gridtype="condor" rsl="" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100"/>
               <per_entry glideins="10000" held="1000" idle="2000"/>
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2"/>
            <remove max_per_cycle="5" sleep="0.2"/>
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False"/>
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="fixed">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr name="CONDOR_ARCH" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="default"/>
            <attr name="CONDOR_OS" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="rhel7"/>
            <attr name="GLEXEC_JOB" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="False"/>
            <attr name="GLIDEIN_Site" const="True" glidein_publish="True" job_publish="True" parameter="True" publish="True" type="string" value="ITB_FC_CE2"/>
            <attr name="USE_CCB" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="string" value="True"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
    'old_ITB_FC_CE3': """      <entry name="ITB_FC_CE3" auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud121.fnal.gov/jobmanager-condor" gridtype="gt2" rsl="(queue=default)(jobtype=single)" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100"/>
               <per_entry glideins="10000" held="1000" idle="2000"/>
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2"/>
            <remove max_per_cycle="5" sleep="0.2"/>
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False"/>
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="fixed">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr name="CONDOR_ARCH" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="default"/>
            <attr name="CONDOR_OS" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="rhel6"/>
            <attr name="GLEXEC_JOB" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="False"/>
            <attr name="GLIDEIN_Site" const="True" glidein_publish="True" job_publish="True" parameter="True" publish="True" type="string" value="ITB_FC_CE2"/>
            <attr name="USE_CCB" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="string" value="True"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
    'ITB_FC_CE3': """      <entry name="ITB_FC_CE3" auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud121.fnal.gov fermicloud121.fnal.gov:9619" gridtype="condor" rsl="" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100"/>
               <per_entry glideins="10000" held="1000" idle="2000"/>
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2"/>
            <remove max_per_cycle="5" sleep="0.2"/>
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False"/>
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="fixed">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr name="CONDOR_ARCH" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="default"/>
            <attr name="CONDOR_OS" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="rhel7"/>
            <attr name="GLEXEC_JOB" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="False"/>
            <attr name="GLIDEIN_Site" const="True" glidein_publish="True" job_publish="True" parameter="True" publish="True" type="string" value="ITB_FC_CE2"/>
            <attr name="USE_CCB" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="string" value="True"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
    'ITB_FC_CE3x4': """     <entry name="ITB_FC_CE3x4" auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud121.fnal.gov fermicloud121.fnal.gov:9617" gridtype="condor" rsl="" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100"/>
               <per_entry glideins="10000" held="1000" idle="2000"/>
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2"/>
            <remove max_per_cycle="5" sleep="0.2"/>
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False"/>
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="partitionable">
               <submit_attrs>
                  <submit_attr name="+xcount" value="4"/>     
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr name="CONDOR_ARCH" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="default"/>
            <attr name="CONDOR_OS" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="rhel7"/>
            <attr name="GLEXEC_JOB" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="False"/>
            <attr name="GLIDEIN_Site" const="True" glidein_publish="True" job_publish="True" parameter="True" publish="True" type="string" value="ITB_FC_CE3x4"/>
            <attr name="USE_CCB" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="string" value="True"/>
            <attr name="GLIDEIN_CPUS" const="True" parameter="True" publish="True" value="4"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
    'Fermicloud-MultiSlots': """      <entry name="Fermicloud-MultiSlots" auth_method="key_pair" enabled="True" gatekeeper="x509://fermicloud.fnal.gov:8444/" gridtype="ec2" rsl="" schedd_name="fermicloud102.fnal.gov" trust_domain="FermiCloud" verbosity="std" vm_id="ami-00000257" vm_type="glideinwms.3cpu" work_dir=".">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5" held="2" idle="2"/>
               <per_entry glideins="5" held="2" idle="2"/>
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="1" sleep="0.2"/>
            <remove max_per_cycle="1" sleep="0.2"/>
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False"/>
            <submit cluster_size="1" max_per_cycle="2" sleep="0.2" slots_layout="partitionable">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr name="CONDOR_ARCH" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="default"/>
            <attr name="CONDOR_OS" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="rhel5"/>
            <attr name="GLEXEC_BIN" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="NONE"/>
            <attr name="GLIDEIN_CPUS" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="int" value="3"/>
            <attr name="GLIDEIN_Max_Idle" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="int" value="300"/>
            <attr name="GLIDEIN_Retire_Time" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="int" value="1209600"/>
            <attr name="GLIDEIN_Retire_Time_Spread" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="int" value="864000"/>
            <attr name="GLIDEIN_Site" const="True" glidein_publish="True" job_publish="True" parameter="True" publish="True" type="string" value="Fermicloud-MultiSlots"/>
            <attr name="USE_CCB" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="string" value="True"/>
            <attr name="VM_DISABLE_SHUTDOWN" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="False"/>
            <attr name="VM_MAX_LIFETIME" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="1209600"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
    'Fermicloud_PP': """      <entry name="Fermicloud_PP" auth_method="key_pair" enabled="True" gatekeeper="x509://fermicloudpp.fnal.gov:8444/" gridtype="ec2" rsl="" schedd_name="fermicloud102.fnal.gov" trust_domain="FermiCloud" verbosity="std" vm_id="ami-00000168" vm_type="glideinwms.4cpu" work_dir=".">
         <config>
            <max_jobs>
               <default_per_frontend glideins="15" held="5" idle="5"/>
               <per_entry glideins="15" held="5" idle="5"/>
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="1" sleep="0.2"/>
            <remove max_per_cycle="1" sleep="0.2"/>
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False"/>
            <submit cluster_size="1" max_per_cycle="2" sleep="0.2" slots_layout="partitionable">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr name="CONDOR_ARCH" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="default"/>
            <attr name="CONDOR_OS" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="rhel5"/>
            <attr name="GLEXEC_BIN" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="NONE"/>
            <attr name="GLIDEIN_CPUS" const="True" glidein_publish="False" job_publish="True" parameter="True" publish="True" type="string" value="4"/>
            <attr name="GLIDEIN_MaxMemMBs_Estimate" const="True" glidein_publish="False" job_publish="True" parameter="True" publish="True" type="string" value="TRUE"/>
            <attr name="GLIDEIN_Max_Idle" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="int" value="7200"/>
            <attr name="GLIDEIN_Retire_Time" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="int" value="1209600"/>
            <attr name="GLIDEIN_Retire_Time_Spread" const="True" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="int" value="864000"/>
            <attr name="GLIDEIN_Site" const="True" glidein_publish="True" job_publish="True" parameter="True" publish="True" type="string" value="Fermicloud_PP"/>
            <attr name="USE_CCB" const="True" glidein_publish="True" job_publish="False" parameter="True" publish="True" type="string" value="True"/>
            <attr name="VM_DISABLE_SHUTDOWN" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="False"/>
            <attr name="VM_MAX_LIFETIME" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="1209600"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
       'ITB_FC_HTC_SIN_CE2': """      <entry auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud378.fnal.gov fermicloud378.fnal.gov:9619" gridtype="condor" name="ITB_FC_HTC_SIN_CE2" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100" />
               <per_entry glideins="10000" held="1000" idle="2000" />
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2" />
            <remove max_per_cycle="5" sleep="0.2" />
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False" />
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="partitionable">
               <submit_attrs>
                <submit_attr name="RequestCpus" value="4" />
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr const="True" glidein_publish="True" job_publish="False" name="GLIDEIN_SINGULARITY_REQUIRE" parameter="True" publish="True" type="string" value="PREFERRED" />
            <attr const="False" glidein_publish="False" job_publish="False" name="CONDOR_ARCH" parameter="True" publish="True" type="string" value="default" />
            <attr const="False" glidein_publish="False" job_publish="False" name="CONDOR_OS" parameter="True" publish="True" type="string" value="rhel7" />
            <attr const="True" glidein_publish="False" job_publish="False" name="GLEXEC_JOB" parameter="True" publish="True" type="string" value="False" />
            <attr const="True" glidein_publish="True" job_publish="True" name="GLIDEIN_Site" parameter="True" publish="True" type="string" value="ITB_FC_HTC_SIN_CE2" />
            <attr const="True" glidein_publish="True" job_publish="True" name="GLIDEIN_CPUS" parameter="True" publish="True" type="string" value="4" />
            <attr const="True" glidein_publish="True" job_publish="False" name="USE_CCB" parameter="True" publish="True" type="string" value="True" />
            <attr name="GLIDEIN_Job_Max_Time" value="1800" type="int" publish="False" parameter="True"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
       'ITB_FC_SIN_CE2': """      <entry auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud378.fnal.gov fermicloud378.fnal.gov:9619" gridtype="condor" name="ITB_FC_SIN_CE2" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100" />
               <per_entry glideins="10000" held="1000" idle="2000" />
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2" />
            <remove max_per_cycle="5" sleep="0.2" />
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False" />
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="partitionable">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr const="True" glidein_publish="True" job_publish="False" name="GLIDEIN_SINGULARITY_REQUIRE" parameter="True" publish="True" type="string" value="PREFERRED" />
            <attr const="False" glidein_publish="False" job_publish="False" name="CONDOR_ARCH" parameter="True" publish="True" type="string" value="default" />
            <attr const="False" glidein_publish="False" job_publish="False" name="CONDOR_OS" parameter="True" publish="True" type="string" value="rhel7" />
            <attr const="True" glidein_publish="False" job_publish="False" name="GLEXEC_JOB" parameter="True" publish="True" type="string" value="False" />
            <attr const="True" glidein_publish="True" job_publish="True" name="GLIDEIN_Site" parameter="True" publish="True" type="string" value="ITB_FC_SIN_CE2" />
            <attr const="True" glidein_publish="True" job_publish="True" name="GLIDEIN_CPUS" parameter="True" publish="True" type="string" value="auto" />
            <attr const="True" glidein_publish="True" job_publish="False" name="USE_CCB" parameter="True" publish="True" type="string" value="True" />
            <attr name="GLIDEIN_Job_Max_Time" value="1800" type="int" publish="False" parameter="True"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
    'ITB_FC_SIN_CE1': """      <entry auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud105.fnal.gov fermicloud105.fnal.gov:9619" gridtype="condor" name="ITB_FC_SIN_CE1" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100" />
               <per_entry glideins="10000" held="1000" idle="2000" />
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2" />
            <remove max_per_cycle="5" sleep="0.2" />
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False" />
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="partitionable">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr const="True" glidein_publish="True" job_publish="False" name="GLIDEIN_SINGULARITY_REQUIRE" parameter="True" publish="True" type="string" value="PREFERRED" />
            <attr const="False" glidein_publish="False" job_publish="False" name="CONDOR_ARCH" parameter="True" publish="True" type="string" value="default" />
            <attr const="False" glidein_publish="False" job_publish="False" name="CONDOR_OS" parameter="True" publish="True" type="string" value="rhel7" />
            <attr const="True" glidein_publish="False" job_publish="False" name="GLEXEC_JOB" parameter="True" publish="True" type="string" value="False" />
            <attr const="True" glidein_publish="True" job_publish="True" name="GLIDEIN_Site" parameter="True" publish="True" type="string" value="ITB_FC_SIN_CE1" />
            <attr const="True" glidein_publish="True" job_publish="True" name="GLIDEIN_CPUS" parameter="True" publish="True" type="string" value="1" />
            <attr const="True" glidein_publish="True" job_publish="False" name="USE_CCB" parameter="True" publish="True" type="string" value="True" />
            <attr name="GLIDEIN_Job_Max_Time" value="1800" type="int" publish="False" parameter="True"/>
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>      
""",
    'ITB_FC_TOK': """      <entry auth_method="grid_proxy" enabled="True" gatekeeper="fermicloud127.fnal.gov fermicloud127.fnal.gov:9619" gridtype="condor" name="ITB_FC_TOK" rsl="" trust_domain="grid" verbosity="std" work_dir="OSG">
         <config>
            <max_jobs>
               <default_per_frontend glideins="5000" held="50" idle="100" />
               <per_entry glideins="10000" held="1000" idle="2000" />
               <per_frontends>
               </per_frontends>
            </max_jobs>
            <release max_per_cycle="20" sleep="0.2" />
            <remove max_per_cycle="5" sleep="0.2" />
            <restrictions require_glidein_glexec_use="False" require_voms_proxy="False" />
            <submit cluster_size="10" max_per_cycle="100" sleep="0.2" slots_layout="fixed">
               <submit_attrs>
               </submit_attrs>
            </submit>
         </config>
         <allow_frontends>
         </allow_frontends>
         <attrs>
            <attr name="CONDOR_VERSION" const="False" glidein_publish="False" job_publish="False" parameter="True" publish="True" type="string" value="8.9.7" comment="needs >= 3.9.1 to enable tokens" />
            <attr const="False" glidein_publish="False" job_publish="False" name="CONDOR_ARCH" parameter="True" publish="True" type="string" value="default" />
            <attr const="False" glidein_publish="False" job_publish="False" name="CONDOR_OS" parameter="True" publish="True" type="string" value="rhel7" />
            <attr const="True" glidein_publish="False" job_publish="False" name="GLEXEC_JOB" parameter="True" publish="True" type="string" value="False" />
            <attr const="True" glidein_publish="True" job_publish="True" name="GLIDEIN_Site" parameter="True" publish="True" type="string" value="ITB_FC_TOK" />
            <attr const="True" glidein_publish="True" job_publish="False" name="USE_CCB" parameter="True" publish="True" type="string" value="True" />
         </attrs>
         <files>
         </files>
         <infosys_refs>
         </infosys_refs>
         <monitorgroups>
         </monitorgroups>
      </entry>
""",
    'No': """
""",
}


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print "%s factory# frontend#   : number or full hostname (no domain). setup used in installation, do not run it multiple times" % sys.argv[0]
        print "%s -a ENTRY_NAME        : add an entry" % sys.argv[0]
        print "%s -d ENTRY_NAME        : remove an entry" % sys.argv[0]
        print "%s -l entries           : list current entries (available and in factory)" % sys.argv[0]
        exit(1)
    special_command=True
    if sys.argv[1]=='-a':
        factory_add(sys.argv[2])
    elif sys.argv[1]=='-d':
        factory_remove(sys.argv[2])
    elif sys.argv[1]=='-l':
        factory_list()
    else:
        special_command=False
    if special_command:
        exit(0) 
    try:
        FACTORY_INT=int(sys.argv[1])
        FACTORY='fermicloud%s.fnal.gov' % sys.argv[1]
    except:
        FACTORY='%s.fnal.gov' % sys.argv[1]
    try:
        FRONTEND_INT=int(sys.argv[2])
        FRONTEND='fermicloud%s.fnal.gov' % sys.argv[2]
    except:
        FRONTEND='%s.fnal.gov' % sys.argv[2]
    fname='/etc/gwms-frontend/frontend.xml'
    if os.path.isfile(fname):
        print "Configuring frontend (%s). Frontend host %s, factory %s. New file: %s.new" % (fname, FRONTEND, FACTORY, fname)
        frontend_config1(fname)
        print "Writing HTC mapfile (/etc/condor/certs/condor_mapfile1)"
        write_htc_map()
    fname='/etc/gwms-factory/glideinWMS.xml'
    if os.path.isfile(fname):
        print "Configuring factory (%s). Frontend host %s, factory %s. New file: %s.new" % (fname, FRONTEND, FACTORY, fname)
        factory_config1(fname)
        print "Writing HTC mapfile"
        write_htc_map()
  


"""
fname='/etc/gwms-frontend/frontend.xml'

tree = ET.ElementTree()
tree.parse(fname)
# process_logs
elem = tree.find('log_retention/process_logs')
elem.append(ET.XML(XML_LOG_ALL))
# factory
elem = tree.find('match/factory')
elem.set('query_expr', 'True')
# collector   
collectors = tree.find('match/factory/collectors')
new_coll = T(XML_COLLECTOR).substitute(dict(factory=FACTORY))
for elem in list(collectors.getchildren()):
        collectors.remove(elem)

collectors.append(ET.XML(new_coll))
# security
elem = tree.find('security')
tree.getroot().remove(elem)
elem = T(XML_SECURITY).substitute(dict(frontend=FRONTEND))    
tree.getroot().append(ET.XML(elem))
#    
# open("%s.new" % fname, 'w')
tree.write("%s.new" % fname)


fname='/etc/gwms-factory/glideinWMS.xml'

elem = tree.find('condor_tarballs')
tree.getroot().remove(elem)
tree.getroot().append(ET.XML(HTC_TARBALLS))
 
for i in entries:
        elem.append(ET.XML(ENTRIES[i]))

e_list = []
elem = tree.find('entries')
for i in elem.getchildren():
        e_list.append(i.get('name'))

print "Entries in Factory: %s" % e_list


# ADD
elem = tree.find('entries')
# to avoid duplicates w/ same name
for i in list(elem.getchildren()):
        if i.get('name')==entry:
            print "Entry %s already there. Removing it." % entry
            elem.remove(i)

print "Adding entry: %s" % entry
elem.append(ET.XML(ENTRIES[entry]))
    
    else:
        print "Entry %s not found" % entry

# REMOVE
elem = tree.find('entries')
for i in list(elem.getchildren()):
        if i.get('name')==entry:
            print "Removing entry: %s" % entry
            elem.remove(i)

"""


