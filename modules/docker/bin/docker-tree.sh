#!/bin/bash

# http://stackoverflow.com/questions/32454679/how-to-see-tree-view-of-docker-images/32455275#32455275

docker run --rm -v \
	/var/run/docker.sock:/var/run/docker.sock \
	nate/dockviz images -t

