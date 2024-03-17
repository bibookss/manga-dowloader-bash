#! /bin/bash

function initialize() {
  # Create a directory to store the downloaded files
  mkdir -p tmp/downloads

  # Create a directory to store the database
  mkdir -p tmp/db
}

function search_manga() {
  read -p "Enter the search term: " term
  echo "Searching for $term..."

  # Make curl silent and follow redirects
  output=$(curl -s "https://manganato.com/search/story/$term")
  
  # Select all <a> elements with class 'item-img bookmark_check'
  selected_links=$(echo "$output" | grep -o '<a[^>]*class="item-img bookmark_check"[^>]*>')
  
  # Declare an array to store tuples of title and href
  declare -a links_array=()
  
  # Loop through selected links
  while IFS= read -r link; do
    # Extract title and href attributes
    title=$(echo "$link" | grep -o 'title="[^"]*' | sed 's/title="//')
    href=$(echo "$link" | grep -o 'href="[^"]*' | sed 's/href="//')
    
    # Store title and href as a tuple in the array
    links_array+=("$title" "$href")
  done <<< "$selected_links"

  # If the first element of the array is an empty string, then no manga was found
  if [[ -z ${links_array[0]} ]]; then
    echo "No manga found!"
    main
  fi
  
  # Output the array
  for ((i = 0; i < ${#links_array[@]}; i += 2)); do
    printf "[%d] %s:\n" "$((i/2+1))" "${links_array[i]}" 
  done

  read -p "Enter the number of the manga you want to download: " number
  title=${links_array[$(((number-1)*2))]}
  href=${links_array[$(((number-1)*2+1))]}
}

function get_latest_chapter() {
  echo "Getting latest chapter for $title..."
  output=$(curl -s "$href")
  latest_chapter=$(echo "$output" | grep -m 1 -o '<a[^>]*rel="nofollow"[^>]*class="chapter-name text-nowrap"[^>]*href="[^"]*"[^>]*title="[^"]*"[^>]*>[^<]*</a>')
  last=$(echo "$latest_chapter" | sed -E 's/.*Chapter ([0-9]*).*/\1/')
  echo "Latest chapter: $last"

}

function select_manga_chapters() {
  read -p "Enter the start chapter: " start
  read -p "Enter the end chapter: " end

  # Initialize list of chapters
  chapters=()
  for ((i = start; i <= end; i++)); do
    # Combine href and chapter number
    chapters+=("$href/chapter-$i")
  done
}

function download_manga_chapters() {
  echo "Downloading chapters $start to $end..."
  for chapter in "${chapters[@]}"; do
    download_manga_chapter $chapter
  done
}

function download_manga_chapter() {
  chapter_link=$1

  # Get the chapter page
  output=$(curl -s "$chapter_link")

  # Extract the image links
  image_links=$(echo "$output" | grep -o '<img[^>]*src="[^"]*"[^>]*>')
  image_links=($(echo "$image_links" | grep -o 'src="[^"]*"' | sed 's/src="//' | sed 's/"//g'))

  # Extract the chapter number
  chapter_number=$(echo "$chapter_link" | sed -E 's/.*chapter-([0-9]*).*/\1/')

  # Create a directory for the chapter
  chapter_dir="tmp/downloads/$title/Chapter-$chapter_number"
  mkdir -p "$chapter_dir"

  echo "Downloading chapter $chapter_number..."

  # Download the images
  for ((i = 0; i < ${#image_links[@]}; i++)); do
    image_link=${image_links[i]}
    image_name=$(printf "%03d" $((i+1)))
    curl -o "$chapter_dir/$image_name.jpg" "$image_link" \
      -H "referer: https://chapmanganato.to/" \
      -H "user-agent: Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36"
  done

  # Add the manga to the database
  echo "$title|Chapter-$chapter_number|false" >> tmp/db/manga.txt

  # Sleep for 1 second to avoid getting blocked
  sleep 2
}

function list_downloaded_manga() {
  echo "Listing downloaded manga..."
  cat tmp/db/manga.txt | column -s '|' -t
}

function delete_downloaded_manga() {
  list_downloaded_manga
  read -p "Enter the title of the manga you want to delete: " title
  rm -rf "tmp/downloads/$title"
  echo "Deleted $title!"
}

function mark_chapter_as_read() {
  read -p "Enter the title of the manga you want to mark as read: " title
  read -p "Enter the chapter number: " chapter
  sed -i '' -e "s/$title|Chapter-$chapter|false/$title|Chapter-$chapter|true/" tmp/db/manga.txt
  echo "Marked $title as read!"
}

function list_unread_manga() {
  echo "Listing unread manga..."
  echo "Title|Chapter|HasRead" | column -s '|' -t
  awk -F '|' '$3 ~ /false/' tmp/db/manga.txt | column -s '|' -t
}

function list_read_manga() {
  echo "Listing read manga..."
  echo "Title|Chapter|HasRead" | column -s '|' -t
  awk -F '|' '$3 ~ /true/' tmp/db/manga.txt | column -s '|' -t
}

function main() {
  initialize

  echo "Welcome to the manga downloader!"

  while true; do
    echo "1. Search for manga"
    echo "2. List downloaded manga"
    echo "3. Delete downloaded manga"
    echo "4. List read manga"
    echo "5. List unread manga"
    echo "6. Mark as read"
    echo "7. Exit"
    read -p "Enter your choice: " choice

    case $choice in
      1)
        search_manga
        get_latest_chapter
        select_manga_chapters
        download_manga_chapters
        ;;
      2)
        list_downloaded_manga
        ;;
      3)
        delete_downloaded_manga
        ;;
      4)
        list_read_manga
        ;;
      5)
        list_unread_manga
        ;;
      6)
        mark_chapter_as_read 
        ;;
      7)
        break
        ;;
      *)
        echo "Invalid choice!"
        ;;
    esac
  done
  echo "Goodbye!"
}

main