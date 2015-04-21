fs = require 'fs'
path = require 'path'
exec = require('child_process').exec

async = require 'async'
program = require 'commander'
request = require 'request-json'
mkdirp = require 'mkdirp'
log = require('printit')
    prefix: 'cozy-locales'

pkg = require './package.json'
version = pkg.version

LOCALES = ['en', 'fr', 'de', 'es']



helpers =

    app: null
    baseUrl: null
    download: (locale, callback) ->
        destPath = path.join '.', 'locales', helpers.app, "#{locale}.coffee"
        client = request.createClient helpers.baseUrl

        client.saveFile "#{locale}.coffee", destPath, (err) ->
            if err
                log.error "Download of #{locale} failed."
            else
                log.info "Download of #{locale} succeeded."
                destPath = path.join '.', 'locales', helpers.app, "#{locale}.json"
                try
                    translations = require "./locales/#{helpers.app}/#{locale}"
                    fs.writeFileSync destPath, JSON.stringify translations, null, 2
                    log.info "#{locale} json file created."
                catch err
                    log.error "Wrong locale file for #{locale}"
            callback err

actions =

    fetchLocales: (app) ->
        helpers.app = app
        if app is 'mobile'
            helpers.baseUrl = "https://raw.githubusercontent.com/cozy/cozy-#{app}/master/www-src/app/locales/"
        else if app is 'proxy'
            helpers.baseUrl = "https://raw.githubusercontent.com/cozy/cozy-#{app}/master/client/locales/"
        else
            helpers.baseUrl = "https://raw.githubusercontent.com/cozy/cozy-#{app}/master/client/app/locales/"
        mkdirp path.join './locales', app
        async.forEach LOCALES, helpers.download, (err) ->
            log.info 'Download finished'


program
    .version(version)
    .usage('<action> <app>')

program
    .command("fetch-locales <app> ")
    .description("Download locales for a given cozy-modules")
    .action actions.fetchLocales


program.parse process.argv

unless process.argv.slice(2).length
    program.outputHelp()
