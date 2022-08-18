# Remember, alias are only interactive, not in scriupts w/o: shopt -s expand_aliases
# bash -i -c 'myalias' will work because makes the shell interactive
# and use -t to force a terminal session (needed to insert interactive input like a password), -tt to force a tesminal also when ssh doesn't have it
# e.g. alias fclremotesettoken="ssh -t -K openstackuigpvm01.fnal.gov  'bash -i -c fclsettoken' 2> /dev/null"
# "$PWD" resolved at definition, '$PWD' resolved at use,  'part1 '"'"'quoted'"'"' part2' adds a single quoted part in a single quote string (string concatenation in shells) 

# Setup GWMS_DEV_USER in the environment as your desired fermicloud UI (openstackuigpvm01) user or substitute here (not needed if it is $USER)
export GWMS_DEV_USER=${GWMS_DEV_USER:-$USER}
# Modify the Git repo if desired
export GWMS_DEV_REPO="https://raw.githubusercontent.com/glideinwms/dev-tools/master"
export GWMS_DEV_REPO_GIT="https://github.com/glideinWMS/dev-tools.git"
# Setup (init and update) add ~/.bash_aliases ~/.bashcache/fclhosts and some files in ~/bin/

#alias mvim="/Applications/MacVim.app/contents/MacOS/MacVim"
alias mvim="open -a MacVim.app $@"
#alias lt='ls --human-readable --size'
alias lt='du -sh * | sort -h'
alias cpv='rsync -ah --info=progress2'
alias ve='python3 -m venv ./venv'
alias va='source ./venv/bin/activate'
alias dfh='df -h -T hfs,apfs,exfat,ntfs,noowners'
# git
alias gpo='git push origin'
alias gitmodified="git status | grep modified | awk '{print \$2}' | tr $'\n' ' '"
alias gitgraph='git log --all --decorate --oneline --graph'
alias cg='cd `git rev-parse --show-toplevel`'
alias cdgwms='cd prog/repos/git-gwms/'
alias cdm='cd-with-memory'
alias pushdm='cd-with-memory pushd'
alias dictlist='curl dict://dict.org/show:db'
alias infoalias='
echo -e "Aliases defined:\n General: lt cpv ve va dfh cl cdm pushdm cg dict dictlist"
echo " To connect to fermicloud: fcl... slv slf sgweb fcl-fe-certs (proxy-creds renewal)"
echo " GWMS: gv.. fe.. fa.."
echo " HTCondor: cv.. cc.. htc_.."
echo " infoalias, fclinit"
'

## For laptop
# Fermicloud
alias fcltokenlocal='OST_PROJECT=${OST_PROJECT:-glideinwms} ; export OS_TOKEN=$(openstack --os-username=$USER  --os-user-domain-name=services --os-project-domain-name=services --os-project-name $OST_PROJECT  --os-auth-url http://131.225.153.227:5000/v3  --os-system-scope all token issue --format json | jq -r '"'"'.id'"'"') && rm -f "$HOME"/.fclcache/token && echo "OST_PROJECT=$OST_PROJECT" > "$HOME"/.fclcache/token && chmod 600 "$HOME"/.fclcache/token && echo "OS_TOKEN_DATE=$(date +%Y-%m-%dT%H:%M:%S%z)" >> "$HOME"/.fclcache/token && echo "OS_TOKEN=$OS_TOKEN" >> "$HOME"/.fclcache/token'
# Will ask for service password
#alias fclremotesettoken="ssh -t -K marcom@openstackuigpvm01.fnal.gov  'bash -i -c fclsettoken' 2> /dev/null"
alias fcltoken="ssh -t -K $GWMS_DEV_USER@openstackuigpvm01.fnal.gov  'bash -i -c fcltokenlocal' 2> /dev/null"
alias fcltokendelete="ssh -t -K $GWMS_DEV_USER@openstackuigpvm01.fnal.gov  'rm -f ~/.fclcache/token' 2> /dev/null"
#alias fclrefreshhosts="ssh -K marcom@fermicloudui.fnal.gov  '. /etc/profile.d/one4x.sh; . /etc/profile.d/one4x_user_credentials.sh; ~marcom/bin/myhosts' > ~/.bashcache/fclhosts"
#alias fclrefreshhosts="ssh -K marcom@fermicloudui.fnal.gov  '~marcom/bin/myhosts -r' > ~/.bashcache/fclhosts"
#alias fclrefreshhosts="ssh -K marcom@fcluigpvm01.fnal.gov  '~marcom/bin/myhosts -r' > ~/.bashcache/fclhosts"
alias fclrefreshhosts="ssh -K $GWMS_DEV_USER@openstackuigpvm01.fnal.gov  '~/bin/myhosts.sh' > ~/.bashcache/fclhosts"
alias fclhosts='cat ~/.bashcache/fclhosts'
alias fclinit='ssh-init-host'
alias fclinfo='gwms-what.sh'
#alias fclui='ssh marcom@fermicloudui.fnal.gov'
alias fclui="ssh $GWMS_DEV_USER@openstackuigpvm01.fnal.gov"
alias fclvofrontend='ssh root@gwms-dev-frontend.fnal.gov'
alias fclfactory='ssh root@gwms-dev-factory.fnal.gov'
alias fclweb='ssh root@gwms-web.fnal.gov'
alias slv='ssh-last ssh root U_vofrontend'
alias slf='ssh-last ssh root U_factory'
alias slce='ssh-last ssh root U_ce'
alias fcl='ssh-last ssh root'
alias fcl025='ssh root@fermicloud025.fnal.gov' 
#alias sgweb='ssh root@gwms-web.fnal.gov'
# htgettoken options: (-r pilot group pilot for wlcg, default) -i fermilab , -i fermilab-test, -i cms
alias fclhtgettoken='htgettoken --minsecs=3580 -v -a fermicloud543.fnal.gov -o '
alias fclhtgettokenfnal='htgettoken --minsecs=3580 -v -a fermicloud543.fnal.gov -i fermilab -o '

## For fermicloud hosts
# GWMS log files (use [N]:n :p to navigate files)
alias gvmain='less /var/log/gwms-frontend/group_main/main.*.log'
alias gvfe='less /var/log/gwms-frontend/frontend/frontend.*.log'
alias gvfa='less /var/log/gwms-factory/server/factory/factory.*.log'
alias gvg0='less /var/log/gwms-factory/server/factory/group_0.*.log'
alias gvel='ls /var/log/gwms-factory/server/ | grep entry'
# gve is a function
# HTCondor CondorView some log file, CondorCommand...
alias cvcoll='less /var/log/condor/CollectorLog'
alias cvsched='less /var/log/condor/SchedLog'
alias cvmaster='less /var/log/condor/MasterLog'
alias cvgm='less /var/log/condor/GridManagerLog.schedd_glideins*'
alias cvcerts='less /etc/condor/certs/condor_mapfile'
alias ccs='condor_status -any'
alias ccsf='condor_status -any -af MyType Name'
alias ccsl="condor_status -any -constraint 'MyType == \"glidefactoryclient\"' -af GlideinMonitorRequestedIdle GlideinMonitorRequestedMaxGlideins GlideinMonitorRequestedIdleCores GlideinMonitorRequestedMaxCores ReqEntryName Name"
alias ccq='condor_q -global -allusers'
#alias ccql='htc_foreach_schedd condor_q -af ClusterId ProcId GlideinEntryName GlideinClient JobStatus Cmd -name'
alias ccql='htc_foreach_schedd -f1 condor_q -allusers -af ClusterId ProcId GlideinEntryName GlideinClient JobStatus Cmd -name'
alias ccqlv='htc_foreach_schedd -v -f1 condor_q -allusers -af ClusterId ProcId GlideinEntryName GlideinClient JobStatus Cmd -name'
alias ccrm='condor_rm -all -name'
alias ccrmg2='su -c "condor_rm -name schedd_glideins2@$HOSTNAME -all" - gfactory'
alias ccrmg3='su -c "condor_rm -name schedd_glideins3@$HOSTNAME -all" - gfactory'
alias ccrmg4='su -c "condor_rm -name schedd_glideins4@$HOSTNAME -all" - gfactory'
alias ccrma='htc_foreach_schedd condor_rm -all -name'

## These are for root on fermicloud hosts
# GWMS manage
alias festart='/bin/systemctl start gwms-frontend'
alias festartall='for s in fetch-crl-cron httpd condor gwms-frontend fetch-crl-boot; do echo "Starting $s"; /bin/systemctl start $s; done'
alias festop='/bin/systemctl stop gwms-frontend'
alias fereconfig='/bin/systemctl stop gwms-frontend; /usr/sbin/gwms-frontend reconfig; /bin/systemctl start gwms-frontend'
alias feupgrade='/bin/systemctl stop gwms-frontend; /usr/sbin/gwms-frontend upgrade; /bin/systemctl start gwms-frontend'
alias fecredrenewal='fcl-fe-certs'  # alias to make it easy to find - renew proxy from certs/creds
alias fetest='su -c "cd condor-test/; condor_submit test-vanilla.sub" -'
alias fastart='/bin/systemctl start gwms-factory'
alias fastartall='for s in fetch-crl-cron httpd condor gwms-factory fetch-crl-boot; do echo "Starting $s"; /bin/systemctl start $s; done'
alias fastop='/bin/systemctl stop gwms-factory'
alias faupgrade='/bin/systemctl stop gwms-factory; /usr/sbin/gwms-factory upgrade ; /bin/systemctl start gwms-factory'
alias fareconfig='/bin/systemctl stop gwms-factory; /usr/sbin/gwms-factory reconfig; /bin/systemctl start gwms-factory'


## Functions
dict() {
  # dict word [dictionary (as from dictlist)]   OR dict word:dictionary
  if [ -n "$2" ]; then
    curl dict://dict.org/d:${1}:${2}
  else
    curl dict://dict.org/d:${1}
  fi
}

translate() {
  # translate word [to [from]]
  # using 3 letters languages as in FreeDict
  local lan_from=${3:-eng}
  local lan_to=${2:-ita}
  dict $1:fd-${lan_from}-${lan_to}
}

cl() {
  # cd and list files
  DIR="$*";
  [ $# -lt 1 ] && DIR=$HOME
  builtin cd "${DIR}" && ls -F --color=auto
}

gwms-test-job() {
  [[ "$1" = "-h" ]] && { echo -e "gwms-test-job [-h | USER [-l | SUBMIT_FILE]]\nSubmitting condor jobs from the USER's ~/condor-test/ directory"; return; }
  local juser=${1:-$GWMS_DEV_USER}
  [[ "$2" = "-l" ]] && { su -c "cd condor-test/; ls *sub" - $juser; return; }
  local job=${2:-test-vanilla.sub}
  if [ $(id -u) -eq 0 ]; then
    local juserdir=$(eval echo "~$juser")
    [[ -e "$job" || -e ${juserdir}/condor-test/$job ]] && su -c "cd ${juserdir}/condor-test/; condor_submit $job" - $juser || su -c "cd ${juserdir}/condor-test/; ls *${job}*" - $juser
  else
    [[ "$PWD" = */condor-test ]] || cd condor-test/
    [[ -e "$job" ]] && condor_submit $job || ls *${job}*
  fi
}

gve() {
  less /var/log/gwms-factory/server/entry_${1#entry_}/${1#entry_}.*.log
}

cd-with-memory() {
  # use cd or pushd and record the directory in bash_aliases_aux BA_LASTDIR
  local cmd=cd
  if [[ "$1" = pushd ]]; then
    cmd=pushd
    shift
  fi
  [ ! -e ~/.bash_aliases_aux ] && touch ~/.bash_aliases_aux
  if [ -n "$1" ]; then
    grep -v "^BA_LASTDIR=" ~/.bash_aliases_aux > ~/.bash_aliases_aux.new
    echo "BA_LASTDIR=\"$1\"" >> ~/.bash_aliases_aux.new
    command mv ~/.bash_aliases_aux.new ~/.bash_aliases_aux
    $cmd "$1"
  else
    . ~/.bash_aliases_aux
    local lastdir=${BA_LASTDIR}
    if [ -n "$lastdir" ]; then
      [ "$cmd" = cd ] && echo "cd to $lastdir"
      $cmd "$lastdir"
    else
      echo "No last dir available"
      false
    fi
  fi
}

ssh-last() {
  # return the full hostname of the last host of the requested type (or do partial name matches), optionally ssh to it
  # valid types: fact, factory, vofe, frontend, vofrontend, web, ce (fermicloud025), INT (fermicloudINT)
  # OpenStack presents all hosts of the project, "U_" prefix to search only user VMs
  # VMs are in reverse order, most recent first
  local dossh=false
  local asroot=false
  local filteruser=
  if [ "$1" = "ssh" ]; then
    dossh=true
    shift
  fi
  if [ "$1" = "root" ]; then
    asroot=true
    shift
  fi  
  local sel="$1"
  if [[ "$sel" == U_* ]]; then
    filteruser="$GWMS_DEV_USER"
    sel="${sel#U_}"
  fi
  [ "$sel" == "factory" ] && sel=fact
  [ "$sel" == "frontend" ] && sel=vofe
  [ "$sel" == "vofrontend" ] && sel=vofe
  [ "$sel" == "web" ] && sel=gwms-web
  #[ "$sel" == "ce" ] && sel=fermicloud025
  [[ "$sel" =~ ^[0-9]+$ ]] && sel="fermicloud$sel"
  if [ -n "$filteruser" ]; then
    myhost=$(grep "$filteruser" ~/.bashcache/fclhosts | grep "$sel" | head -n 1 | cut -d ' ' -f 3 )
  else
    myhost=$(grep "$sel" ~/.bashcache/fclhosts | head -n 1 | cut -d ' ' -f 3 )
  fi
  if [ -z "$myhost" ]; then
    [[ ! "$sel" =~ ^fermicloud[0-9]+\.fnal\.gov$ ]] && { echo "Host $1 ($sel) not found on fermicloud list."; return 1; }
    myhost=$sel
  fi
  shift
  echo $myhost
  if $dossh; then
    if $asroot; then
      ssh root@$myhost "$@"
    else
      ssh $myhost "$@"
    fi
  fi
}

ssh-init-host() {
  # init a fermicloud node
  local hname=$(ssh-last $1)
  local huser=${2:-root}
  echo "Initializing ${huser}@${hname}"
  #scp "$HOME"/prog/repos/git-gwms/gwms-tools/.bash_aliases ${huser}@${hname}: >/dev/null && ssh ${huser}@${hname}  ". .bash_aliases && aliases-update"
  #ssh ${huser}@${hname}  "curl -L -o $HOME/.bash_aliases $GWMS_DEV_REPO/.bash_aliases 2>/dev/null" && ssh ${huser}@${hname}  ". .bash_aliases && aliases-update"
  ssh ${huser}@${hname}  "curl -L -o ~/.bash_aliases $GWMS_DEV_REPO/.bash_aliases 2>/dev/null && . ~/.bash_aliases && aliases-update"
}

fcldownload() {
  # download from repo and make executable if -x is first parameter
  if [ "$1" == clone ]; then
    git clone $GWMS_DEV_REPO_GIT
    return 0
  fi
  local make_exe=false
  [ "$1" == "-x" ] && { make_exe=true; shift; }
  local dfile="$1"
  if [ -n "$dfile" ]; then
    curl -L -o "$dfile" "$GWMS_DEV_REPO/$(basename "$dfile")"
    if head -n 1  "$dfile" | grep -q "404: Not Found" ; then
      echo "URL not found ($GWMS_DEV_REPO/$(basename "$dfile")). Removing file ("$dfile")."
      rm "$dfile"
    else
      $make_exe && chmod +x "$dfile"
    fi
  fi
}

fcl-fe-certs() {
  # 1. pilot proxy path or file name (default: /etc/gwms-frontend/mm_proxy)
  # some checks to avoid running as regular user or on a host that is not the frontend
  command -v voms-proxy-init  >/dev/null || { echo "voms-proxy-init not found. aborting"; return 1; }
  [[ $(id -u) -ne 0 ]] && { echo "must run as root"; return 1; }
  local pilot_proxy=$1
  [[ -n "$pilot_proxy" ]] && pilot_proxy=/etc/gwms-frontend/mm_proxy
  [[ "$pilot_proxy" = /* ]] || pilot_proxy=/etc/gwms-frontend/"$pilot_proxy"
  pushd /etc/grid-security/
  grid-proxy-init -cert hostcert.pem -key hostkey.pem -valid 999:0 -out /etc/gwms-frontend/fe_proxy
  popd
  /bin/cp /etc/gwms-frontend/fe_proxy /etc/gwms-frontend/vo_proxy
  kx509
  voms-proxy-init -rfc -dont-verify-ac -noregen -voms fermilab -valid 500:0
  /bin/cp /tmp/x509up_u0 /etc/gwms-frontend/mm_proxy
  chown frontend: /etc/gwms-frontend/*
  # Check all proxies
  echo "Proxy renewed (/etc/gwms-frontend/vo_proxy, /etc/gwms-frontend/mm_proxy), now checking..."
  if command -v gwms-check-proxies.sh >/dev/null; then
    gwms-check-proxies.sh
  elif [ -x ~marcom/bin/gwms-check-proxies.sh ]; then
    ~marcom/bin/gwms-check-proxies.sh
  else
    echo "No gwms-check-proxies found"
  fi
}

aliases-update() {
  [ -e "$HOME/.bash_aliases" ] && command cp -f "$HOME"/.bash_aliases "$HOME"/.bash_aliases.bck
  if ! curl -L -o $HOME/.bash_aliases $GWMS_DEV_REPO/.bash_aliases 2>/dev/null; then
    echo "Download from github.com failed. Update failed."
    return 1
  fi
  if ! grep "# Added by alias-update" $HOME/.bashrc >/dev/null; then
    cat >> $HOME/.bashrc << EOF
# Added by alias-update
export PATH="\$PATH:\$HOME/bin"
if [ -e \$HOME/.bash_aliases ]; then
  source \$HOME/.bash_aliases
fi
# End from alias-update
EOF
  fi
  # copy also some binaries
  mkdir -p "$HOME"/.fclcache
  mkdir -p "$HOME"/bin
  for i in gwms-clean-logs.sh gwms-setup-script.py gwms-what.sh gwms-check-proxies.sh myhosts.sh 99_debug.config; do
    curl -L -o $HOME/bin/$i $GWMS_DEV_REPO/$i 2>/dev/null && chmod +x $HOME/bin/$i
    [[ $? -ne 0 ]] && echo "Error downloading $i. Continuing."
  done
  # If root, update some system files. This only for fermicloud hosts
  if [[ -w /etc/profile && "$(hostname)" = fermicloud* ]]; then
    if ! grep "# Added by alias-update" /etc/profile >/dev/null; then
      cat >> /etc/profile << EOF
# Added by alias-update
[ -f /etc/motd.local ] && { tput setaf 2; cat /etc/motd.local; tput sgr0; }
tput setaf 2
if [ -x /root/bin/gwms-what.sh ]; then
  /root/bin/gwms-what.sh
elif [ -x "$HOME/bin/gwms-what.sh" ]; then
  "$HOME/bin/gwms-what.sh"
fi
tput sgr0
# End from alias-update
EOF
    fi
  fi
  # source alias definitions to load updates
  . $HOME/.bash_aliases
}

# HTC functions
htc_job_status() {
  local htc_short=true
  if $htc_short; then
    case $1 in
    0)  echo U;;
    1)  echo  I;;
    2)  echo  R;;
    3)  echo  X;;
    4)  echo  C;;
    5)  echo  H;;
    6)  echo  E;;
    esac
  else
    case $1 in
    0)  echo Unexpanded;;
    1)  echo  Idle;;
    2)  echo  Running;;
    3)  echo  Removed;;
    4)  echo  Completed;;
    5)  echo  Held;;
    6)  echo  Submission_err;;
    esac
  fi
}

htc_filter1() {
  while read -r a b c d e rest; do
    if [[ "$a" == "#"* ]]; then
      echo "$a $b $c $d $e $rest"
    else
      printf '%i.%i\t%s %s %s %s\n' "$a" "$b" "$c" "${d%%-fn*}" "$(htc_job_status "$e")" "$rest"
    fi
  done
}

htc_foreach_schedd() {
  local verbose=false
  local filter=
  if [[ "$1" = "-v" ]]; then
    verbose=true
    shift
  fi
  if [[ "$1" = "-f1" ]]; then
    filter=htc_filter1
    shift
  fi
  local sc_list="$(condor_status -schedd -af Name)"
  for i in $sc_list; do
    $verbose && echo "# $i"
    if [[ -z "$filter" ]]; then
      "$@" $i
    else
      "$@" $i | $filter
    fi
  done
}

