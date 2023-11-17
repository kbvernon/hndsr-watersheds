
function build_map(json_src, csv_src, basemap_src, div_id) {

    function make_label(x) {

        return `
        <br>
        <b style='font-size:1.7em; text-decoration: underline;'>${x['name']}</b>        <br>
        <br>
        <b>ID: </b> ${x['hydrologic_unit']}        <br>
        <b>Basin: </b> ${x['basin']}        <br>
        <b>Year: </b> ${x['year']}        <br>
        <b>Count:</b> ${x['rooms']}        <br>
        <b>Area: </b> ${x['area_km2']} km<sup>2</sup>        <br>
        <b>Density:</b> ${x['density']}        <br>
        <b>Log Density:</b> ${x['log_density']}        
        <br>
        `

    };

    function make_frame(x, year) {

        var g = x.filter((row) => row['year'] == year);

        var z = g.map((row) => row["log_density"]);
        var locations = g.map((row) => row["hydrologic_unit"]);
        var labels = g.map((row) => make_label(row));

        return {data: [{z: z, locations: locations, text: labels}], name: year}

    };

    function make_step(year) {

        return {
            label: year.toString(),
            method: "animate",
            args: [[year], {
                mode: "immediate",
                transition: {duration: 300},
                frame: {duration: 300}
            }]
        }

    };

    function unique(x, t={}){ return x.filter((z) => !(t[z]=z in t)) };

    d3.json(json_src)
            .then((x) => {            

                d3.csv(csv_src)
                    .then((y) => {

                        var frames = [];
                        var slider_steps = [];
                        var year = 750;

                        for (var i = 0; i <= 34; i++) {

                            frames[i] = make_frame(y, year);
                            slider_steps.push(make_step(year));
                            year = year + 25;

                        }

                        var selected_locations = y.map((z) => z["hydrologic_unit"]);

                        var colorbar = {
                            orientation: "h", 
                            x: 0, 
                            y: 1.02, 
                            xanchor: "left",
                            yanchor: "bottom",
                            xref: "paper",
                            yref: "paper",
                            xpad: 0,
                            ypad: 0,
                            len: 0.36,
                            thickness: 20,
                            tick0: -11.5,
                            dtick: 3.5,
                            title: {
                                text: "Log Density", 
                                font: {color: "black", size: 20},
                                side: "top"
                            }
                        };
                            
                        var data = [{
                            type: "choroplethmapbox",
                            geojson: x,
                            featureidkey: "properties.hydrologic_unit",
                            locations: unique(selected_locations),
                            z: frames[0].data[0].z,
                            zmin: -12,
                            zmax: 3,
                            text: frames[0].data[0].text,
                            hoverinfo: "text",
                            hoverlabel: {align: "left", namelength: 0},
                            alpha_stroke: 1,
                            sizes: [10,100],
                            spans: [1,20],
                            colorscale: "Viridis",
                            marker: {opacity: 0.45, line: {color: "#878e99"}},
                            colorbar: colorbar                                     
                        }];

                        var basemap = {
                            sourcetype: "raster",
                            source: [ basemap_src ],
                            below: "traces"
                        };

                        var administrative_labels = {
                            sourcetype: "raster",
                            source: [ "https://server.arcgisonline.com/arcgis/rest/services/Reference/World_Reference_Overlay/MapServer/tile/{z}/{y}/{x}" ],
                            below: "traces"
                        };

                        var update_menus = {
                            x: 0.1,
                            y: 0,
                            xanchor: "right",
                            yanchor: "top",
                            showactive: false,
                            direction: "left",
                            type: "buttons",
                            pad: {"t": 15, "r": 10},
                            buttons: [{
                              method: "animate",
                              args: [null, {
                                fromcurrent: true,
                                transition: { duration: 200 },
                                frame: { duration: 400 }
                              }],
                              label: "Play"
                            }, {
                              method: "animate",
                              args: [
                                [null],
                                {
                                  mode: "immediate",
                                  transition: { duration: 0 },
                                  frame: { duration: 0 }
                                }
                              ],
                              label: "Pause"
                            }]
                        };

                        var slider = {
                            active: 0,
                            steps: slider_steps,
                            x: 0.1,
                            y: 0,
                            xanchor: "left",
                            yanchor: "top",
                            len: 0.89,
                            pad: {t: 15, b: 0},
                            currentvalue: { visible: false },
                            transition: {
                              duration: 200,
                              easing: "linear-in-out"
                            }
                        };

                        var layout = {
                            dragmode: "zoom",
                            mapbox: {
                                style: "white-bg",
                                layers: [ basemap, administrative_labels ],
                                center: {lon: -107.82422, lat: 34.78155},
                                zoom: 4.6
                            },
                            updatemenus: [ update_menus ],
                            sliders: [ slider ],
                            margin: { r: 0, t: 0, b: 0, l: 0 },
                            width: 900,
                            height: 550
                        };

                        Plotly.newPlot(div_id, data, layout)
                            .then(() => Plotly.addFrames(div_id, frames));  

                    });                        

            });

};
