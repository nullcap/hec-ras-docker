#! /bin/bash

## Uncomment and set the below vars if you are moving data to/from an s3 bucket. If S3_BUCKET_NAME is defined, the container will attempt to mount the bucket
## NOTE: you can override any of the configured vars in your 'docker run' command
#export AWS_ACCESS_KEY=YOURAWSACCESSKEY
#export AWS_SECRET_ACCESS_KEY=YOURAWSSECRETACCESSKEY
#export S3_BUCKET_NAME=YOURS3BUCKETNAME

## source config file if it exists
if [ -f /project/config ]; then
  source /project/config
fi

## If the user has configured Amazon s3 bucket storage, mount it
if [[ -v S3_BUCKET_NAME ]]
then 

	## set vars for mounting
	echo "S3 configured, mounting bucket"
	export S3_MOUNT_RESULT=/results
	export S3_MOUNT_PROJECT=/project

	# configure s3fs password file
	echo $AWS_ACCESS_KEY:$AWS_SECRET_ACCESS_KEY > /root/.passwd-s3fs
	chmod 600 /root/.passwd-s3fs

	## mount the bucket
	s3fs $S3_BUCKET_NAME $S3_MOUNT_PROJECT -o passwd_file=/root/.passwd-s3fs
	s3fs $S3_BUCKET_NAME $S3_MOUNT_RESULT -o passwd_file=/root/.passwd-s3fs
	
fi

## If user hasnt overriden t he threads var, attempt to use max number of threads available.
if [[ -v NUM_THREADS ]]
then

	## inform the user
	echo "Thread override configured, using new value"
	echo "Configured thread count: "$NUM_THREADS

else 	

	## Determine the hardware Vendor. Currently only supports Intel and AMD. 
	model_search=("Intel" "AMD")

	model=$(lscpu | grep -i vendor | awk -F ":" '{print $2}' | tr -d '[:blank:]')

	if [[ "$model" == "GenuineIntel" ]]
	then 

		## inform the user
		echo "This system has an Intel processor, and should perform at optimal speeds."
		model="Intel" 

	elif [[ "$model" == "AuthenticAMD" ]]
	then 

		## inform the user
		echo "This system has an AMD processor, and may not perform optimally. Please check the current status of MKL and OMP support on AMD hardware."
		model="AMD"

	else

		## inform the user, then exit
		echo "This sysetem is running on unsupported hardware. This container only works on Intel and AMD systems. Closing application."
		exit 1

	fi
	
	## Determine the hardware specs. If you want to exclude threads in the the math, remove it from the array below.
	info_search=("Socket" "Core" "Thread")

	## Set this to 1, because 1*anything=$anything. This also becomes the min value in the event of an error. 
	NUM_THREADS="1"

	## Searching for search terms listed above

	for i in "${info_search[@]}"
	do 
			## do the search
        	found=$(lscpu | grep -e $i | grep -v $model | awk -F ":" '{print $2}' | tr -d '[:blank:]')
        	## multiply the output together for each new result
			NUM_THREADS=$(($NUM_THREADS*$found))

	done

	## inform the user
	echo "Configured thread count: "$NUM_THREADS
	
fi

## If user hasnt overriden the memory var, attempt to use all available memory.
if [[ -v NUM_MEMORY ]]
then

	## inform the user
	echo "Memory override configured, using new value"
	echo "Configured memory allocation: "$NUM_MEMORY

else

	## do the search
	NUM_MEMORY=$(cat /proc/meminfo | grep "MemTotal" | awk -F ":" '{print $2}' | tr -d '[:blank:]'| tr -d 'kB')
	
	## The above search always prints the memory in "K"
	echo "Configured memory allocation: "$NUM_MEMORY"K"

fi

## Set ENV based on hardware available
ulimit -s unlimited
export MKL_SERIAL=OMP
export MKL_DOMAIN_PARDISO=$NUM_THREADS
export MKL_DOMAIN_BLAS=$NUM_THREADS
export MKL_BLAS=$NUM_THREADS
export OMP_DYNAMIC=FALSE
export OMP_NUM_THREADS=$NUM_THREADS
export OMP_THREAD_LIMIT=$NUM_THREADS
export OMP_STACKSIZE=$NUM_MEMORY
export OMP_PROC_BIND=TRUE

## sync the project data into the appropriate directory
echo "Syncing project data into container env. This may take a bit."
rsync -a /project/ /hecras/project

# symlink the results directory to make it easier for the user to reach within their project bash script.
ln -s /results/ /hecras/project/results

## run the provided run scripts in the order they appear within the directory structure. 
cd /hecras/project && chmod +x ./$PROJECT.sh && ./$PROJECT.sh
