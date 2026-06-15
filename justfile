lint:
    rumdl check --fix

serve:
    podman run --rm -it \
      -v "{{justfile_directory()}}":/site:Z \
      -v realsergiy_gems:/usr/local/bundle \
      -w /site -p 127.0.0.1:4000:4000 -p 127.0.0.1:35729:35729 \
      docker.io/library/ruby:3.4 \
      bash -c "bundle install && printf '\n  ➜  open http://127.0.0.1:4000\n\n' && bundle exec jekyll serve --livereload --force_polling --host 0.0.0.0"
