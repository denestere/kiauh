#TODO:
# - check for existing/running octoprint service
# - ask for permission to disable octoprint service

dwc2_install_routine(){
  if [ -d $KLIPPER_DIR ]; then
    # check for existing installation
      if [ -d $DWC2FK_DIR ] && [ -d $DWC2_DIR ]; then
        ERROR_MSG=" Looks like DWC2 is already installed!\n Skipping..."
        return
      fi
    stop_klipper
    #disable octoprint service if installed
      if systemctl is-enabled octoprint.service -q &>/dev/null; then
        disable_octoprint_service
      fi
    install_tornado
    install_dwc2fk && dwc2fk_cfg
    install_dwc2
    dwc2_reverse_proxy_dialog
    start_klipper
  else
    ERROR_MSG=" Please install Klipper first!\n Skipping..."
  fi
}

install_tornado(){
  if [ ! -d $TORNADO_DIR1 ]; then
    #check for dependencies
    dep=(virtualenv)
    dep_check
    #execute operation
    status_msg "Installing Tornado 5.1.1 ..."
    cd ${HOME}
    PYTHONDIR="${HOME}/klippy-env"
    virtualenv ${PYTHONDIR}
    ${PYTHONDIR}/bin/pip install tornado==5.1.1 && ok_msg "Tornado 5.1.1 successfully installed!"
  else
    ok_msg "Looks like Tornado 5.1.1 is already installed! Continue..."
  fi
}

install_dwc2fk(){
  cd ${HOME}
  status_msg "Cloning DWC2-for-Klipper repository ..."
  git clone $DWC2FK_REPO && ok_msg "DWC2-for-Klipper successfully cloned!"
  #create a web_dwc2.py symlink if not already existing
  if [ -d $KLIPPER_DIR/klippy/extras ] && [ ! -e $KLIPPER_DIR/klippy/extras/web_dwc2.py ]; then
    status_msg "Creating web_dwc2.py Symlink ..."
    ln -s $DWC2FK_DIR/web_dwc2.py $KLIPPER_DIR/klippy/extras/web_dwc2.py && ok_msg "Symlink created!"
  fi
}

dwc2fk_cfg(){
  while true; do
    echo -e "${cyan}"
    read -p "###### Do you want to create the config now? (Y/n): " yn
    echo -e "${default}"
    case "$yn" in
    Y|y|Yes|yes|"") create_dwc2fk_cfg; break;;
    N|n|No|no) break;;
    esac
  done
}

create_dwc2fk_cfg(){
  echo -e "/=================================================\ "
  echo -e "|  1) [Default configuration]                     | "
  echo -e "|  2) [Custom configuration]                      | "
  echo -e "|  3) [Skip]                                      | "
  echo -e "\=================================================/ "
  while true; do
    read -p "Please select: " choice; echo
    case "$choice" in
    1) dwc2fk_default_cfg && ok_msg "Config written ..."; break;;
    2) create_dwc2fk_custom_cfg && ok_msg "Config written ..."; break;;
    3) echo "Skipping ..."; break;;
    esac
  done
}

dwc2fk_default_cfg(){
  cat <<DWC2 >> $PRINTER_CFG

##########################
### CREATED WITH KIAUH ###
##########################
[virtual_sdcard]
path: ~/sdcard

[web_dwc2]
printer_name: my_printer
listen_adress: 0.0.0.0
listen_port: 4750
web_path: dwc2/web
##########################
##########################
DWC2
}

create_dwc2fk_custom_cfg(){
  echo -e "${cyan}"
  read -e -p "Printer name: " -i "my_printer" PRINTER_NAME
  read -e -p "Listen adress: " -i "0.0.0.0" LISTEN_ADRESS
  read -e -p "Listen port: " -i "4750" LISTEN_PORT
  read -e -p "Web path: " -i "dwc2/web" WEB_PATH
  echo -e "${default}"
  DWC2_CFG=$(cat <<DWC2

##########################
### CREATED WITH KIAUH ###
##########################
[virtual_sdcard]
path: ~/sdcard

[web_dwc2]
printer_name: $PRINTER_NAME
listen_adress: $LISTEN_ADRESS
listen_port: $LISTEN_PORT
web_path: $WEB_PATH
##########################
##########################
DWC2
)
  echo "The following lines will be written:"
  echo -e "$DWC2_CFG"
  while true; do
    echo -e "${cyan}"
    read -p "###### Write now (Y) or start over (n)? (Y/n): " yn
    echo -e "${default}"
    case "$yn" in
      Y|y|Yes|yes|"") echo -e "$DWC2_CFG" >> $PRINTER_CFG; break;;
      N|n|No|no) create_dwc2fk_custom_cfg;;
    esac
  done
}

install_dwc2(){
  #the update_dwc2 function does the same as installing dwc2
  update_dwc2 && ok_msg "DWC2 Web UI installed!"
}

dwc2_reverse_proxy_dialog(){
  top_border
  echo -e "|  If you want to have a nicer URL or simply need/want  | "
  echo -e "|  DWC2 to run on port 80 (http's default port) you     | "
  echo -e "|  can set up a reverse proxy to run DWC2 on port 80.   | "
  bottom_border
  while true; do
    echo -e "${cyan}"
    read -p "###### Do you want to set up a reverse proxy now? (Y/n): " yn
    echo -e "${default}"
    case "$yn" in
      Y|y|Yes|yes|"") dwc2_reverse_proxy; break;;
      N|n|No|no) break;;
    esac
  done
}

dwc2_reverse_proxy(){
  if ! [[ $(dpkg-query -f'${Status}' --show nginx 2>/dev/null) = *\ installed ]]; then
    sudo apt-get install nginx -y
  fi
  cat ${HOME}/kiauh/resources/dwc2_nginx.cfg > ${HOME}/kiauh/resources/dwc2
  sudo mv ${HOME}/kiauh/resources/dwc2 /etc/nginx/sites-available/dwc2
  if [ -e /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
  fi
  if [ ! -e /etc/nginx/sites-enabled/dwc2 ]; then
    sudo ln -s /etc/nginx/sites-available/dwc2 /etc/nginx/sites-enabled/
  fi
  restart_nginx
  create_custom_hostname
}