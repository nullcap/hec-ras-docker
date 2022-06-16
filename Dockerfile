## RHEL 8 / CENTOS 8 based linux container
FROM rockylinux:8

## Required ENV
ENV RAS_LIB_PATH=/hecras/libs:/hecras/libs/mkl:/hecras/libs/rhel_8
ENV LD_LIBRARY_PATH=$RAS_LIB_PATH:$LD_LIBRARY_PATH
ENV RAS_EXE_PATH=/hecras/Ras_v61/Release
ENV PATH=$RAS_EXE_PATH:$PATH

## Load the hecras application. Make sure you have the zip file of HEC-RAS in the same directory as this dockerfile!  
#COPY HEC-RAS_610_Linux.zip /tmp
RUN wget -O /tmp/HEC-RAS_610_Linux.zip https://www.hec.usace.army.mil/software/hec-ras/downloads/HEC-RAS_610_Linux.zip

## Load the project files directly, with run script.  Make sure you have this directory in the same directory as this dockerfile!
#COPY project/ /hecras/project

## Load run.sh for container management
COPY run.sh /hecras

## Load Readme
COPY README.md /hecras

WORKDIR /root/
## Install packages, uncompress the software, place it in the correct location, cleanup unneeded files. 
RUN yum install -y epel-release && \
	yum install -y unzip rsync bc vim nano automake python39 python39-pip s3fs-fuse && \
	pip3 install --upgrade pip && pip3 --no-cache-dir install --upgrade awscli && \
	unzip /tmp/HEC-RAS_610_Linux.zip && \
	unzip HEC-RAS_610_Linux/RAS_Linux_test_setup.zip && \
	unzip HEC-RAS_610_Linux/remove_HDF5_Results.zip && \
	mv RAS_Linux_test_setup/* /hecras/ && \
	mv remove_HDF5_Results.py /hecras/ && \
	rm -rf /tmp/HEC-RAS_610_Linux.zip HEC-RAS_610_Linux/ RAS_Linux_test_setup/ Python_script_for_removing_Results_HDF_datagroup.docx  ; \
	chmod +x /hecras/project/run.sh ; \
	chmod +x /hecras/Ras_v61/Debug/* ; \
	chmod +x /hecras/Ras_v61/Release/* ; \
	mkdir /results ; \
	rm -rf /hecras/Muncie

## Where the shell scripts are. Execution happens here. 
WORKDIR /hecras/

## Actual work being done. 
CMD ["/bin/bash", "./run.sh"]
