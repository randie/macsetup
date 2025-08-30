#!/bin/bash
#If you run this without docker-compose running you will delete some shared base images you may prefer to keep
#and will have to re-download them when you restart docker-compose

#Error if I reference variables that have not been initialized
set -u

#containers I have
existingContainers=$(
  docker --tlsverify=false ps -a --no-trunc=true | #get all existing containers
    tail +2 #drop the header line
  )

existingContainersWithIds=$(
  echo "$existingContainers" | 
    awk '{print $1 " " $2}' #select the container id and image name
  )

existingContainerImageNames=$(
  echo "$existingContainersWithIds" | 
    awk '{print $2}' #select the image name
  )

#images I care about
dockerComposeImageNames=$(
  grep 'image:' docker-compose.yml | #select images 
    grep -v '#' | #that are not commented out
    awk '{print $2}' | #select the image name
    sed 's/:latest//' | #trim off :latest tag
    sort
  )

runningImageNames=$(
  docker --tlsverify=false ps -a -f status=running --no-trunc=true | #get containers that are running
    tail +2 | #drop the header line
    awk '{print $2}' | #select the image name
    sort
  )

imagesToKeep=$(
  printf "%s\n" "$dockerComposeImageNames" "$runningImageNames" | #concatenate docker compose and running image names
    sort | #lines need to be sorted before sending to uniq
    uniq | #filter out duplicates
    grep "$existingContainerImageNames" #select only the images that are existing on the system
  )

#get ids for images I want to keep
imageIdsToKeep=$(
  echo "$imagesToKeep" | 
    xargs docker --tlsverify=false inspect -f '{{.Id}}' #lookup image id
  )


#things to remove
#existing containers not referencing images to keep
containersToRemoveWithIds=$(
  echo "$existingContainersWithIds" | 
    grep -v "$imagesToKeep" #select only containers not referencing images to keep
  )
 
echo "Removing unused docker containers..."
echo "$containersToRemoveWithIds" | 
  awk '{print $1}' | #select container id
  xargs docker --tlsverify=false rm -v #remove containers
 
echo "Removing dangling images..."
docker --tlsverify=false images --no-trunc -q -f dangling=true | #get dangling images
  xargs echo docker --tlsverify=false rmi #remove dangling images

echo "Removing unused docker images..."
remainingImages=$(
  docker --tlsverify=false images --no-trunc=true | #get remaining images
    tail +2 #drop header line
  )

imagesToRemove=$(
  echo "$remainingImages" | 
    grep -v "$imageIdsToKeep" #filter out images I want to keep
  )

echo "$imagesToRemove" | 
  awk '{print "\t" $1 ":" $2}' #print image name to be removed. This will print : if there are no images to remove.

echo "$imagesToRemove" | 
  awk '{print $3}' | #select image ids
  xargs echo docker --tlsverify=false rmi #remove images
