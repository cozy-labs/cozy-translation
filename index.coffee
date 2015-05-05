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

getLocalePath = (app) ->
    if app is 'mobile' then 'www-src/app/locales/'
    else if app is 'proxy' then 'client/locales/'
    else 'client/app/locales/'

# convert translation to coffee files
# @TODO : make me make bettter coffee
toCoffee = (translations, level = 1) ->
    out = if level is 1 then "module.exports =\n"
    else ""
    white = new Array(level*5).join(' ')
    for key, value of translations
        if typeof value isnt 'string'
            value = "\n" + toCoffee value, level + 1
        else
            # value may contains \n, use """
            value = '"""' + value + '"""'
        out += white + '"' + key + '":' + value + "\n"
    return out


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

    getResourceName: (callback) ->
        client = request.createClient 'https://www.transifex.com/api/2/project/'
        client.setBasicAuth('aenario','cozytransi')
        client.get "cozy-#{helpers.app}/resources/", (err, res, resources) ->
            if err
                callback new Erorr "Error fetching resources"
            else if resource = resources?[0]?.slug
                callback null, resource
            else
                callback new Erorr "No resources"


    downloadTransifex: (locale, callback) ->
        client = request.createClient 'https://www.transifex.com/api/2/project/'
        client.setBasicAuth('aenario','cozytransi')
        urlPath = "cozy-#{helpers.app}" +
                  "/resource/#{helpers.resource}" +
                  "/translation/#{locale}/"
        localesPath = path.resolve getLocalePath(helpers.app)
        destPath = path.join localesPath, "#{locale}.transifex.coffee"
        client.get urlPath, (err, res, transijson) ->
            if err
                callback "Error fetching #{urlPath} : #{err.stack}"
            else
                translations = JSON.parse transijson.content
                fs.writeFileSync destPath, toCoffee translations
                callback null



actions =

    fetchLocales: (app) ->
        helpers.app = app
        helpers.baseUrl = "https://raw.githubusercontent.com/cozy/cozy-#{app}/"
        helpers.baseUrl += getLocalePath(app)
        mkdirp path.join './locales', app
        async.forEach LOCALES, helpers.download, (err) ->
            log.info 'Download finished'

    fetchFromTransifex: ->
        npmPackage = require path.resolve 'package.json'
        helpers.app = npmPackage.name.replace('cozy-', '')

        helpers.getResourceName (err, resource) ->
            helpers.resource = resource
            async.forEach LOCALES, helpers.downloadTransifex, (err) ->
                console.log err if err
                console.log "done"

    status: ->
        npmPackage = require path.resolve 'package.json'
        app = npmPackage.name.replace('cozy-', '')
        localePath = path.resolve(getLocalePath(app)) + '/'
        require 'coffee-script/register'
        warnings = []
        refKeys = null
        refLocale = null

        for locale in LOCALES
            try localTranslations = require localePath + locale
            catch
                console.log 'NO LOCAL TRANSLATION FOR', locale
                continue
            try transiTranslations = require localePath + locale + '.transifex'
            catch
                console.log 'NO TRANSIFEX FOR', locale
                continue
            localKeys = Object.keys(localTranslations)
            transiKeys = Object.keys(transiTranslations)
            removed = (key for key in localKeys when key not in transiKeys)
            added   = (key for key in transiKeys when key not in localKeys)

            if added.length
                console.log 'KEYS IN TRANSIFEX BUT NOT LOCAL', locale, added

            if removed.length
                console.log 'KEYS IN LOCAL BUT NOT TRANSIFEX', locale, removed

            diff = []
            for key in localKeys
                if typeof localTranslations[key] is 'string' and
                typeof transiTranslations[key] is 'string' and
                localTranslations[key] isnt transiTranslations[key]
                    diff.push key
            if diff.length
                console.log 'KEYS DIFFERENT LOCAL AND TRANSIFEX', locale, diff

            unless refLocale
                refKeys = localKeys
                refLocale = locale
                continue

            inThisNotRef = (key for key in localKeys when key not in refKeys)
            inRefNotThis = (key for key in refKeys when key not in localKeys)

            if inRefNotThis.length
                console.log 'KEY IN', refLocale, 'NOT IN', locale, inRefNotThis
            if inThisNotRef.length
                console.log 'KEY IN', locale, 'NOT IN', refLocale, inThisNotRef






program
    .version(version)
    .usage('<action> <app>')

program
    .command("fetch-locales <app> ")
    .description("Download locales for a given cozy-modules")
    .action actions.fetchLocales

program
    .command('transifetch')
    .description("Refresh the cwd module with transifex locales")
    .action actions.fetchFromTransifex

program
    .command('status')
    .description('Check if everything is awesome')
    .action actions.status


program.parse process.argv

unless process.argv.slice(2).length
    program.outputHelp()
