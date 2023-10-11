// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-nocheck
import './Sunburst.css';

import { FileDownload } from '@mui/icons-material';
import { Button } from '@mui/material';
import { Box, Tooltip } from '@mui/material';
import * as d3 from 'd3';
import { useEffect, useRef, useState } from 'react';

function updateTotalHours(node, totalHours) {
  if (node?.children) {
    const newTotalHours = node.children.reduce((total, d) => {
      total += d.value;
      return total;
    }, 0);
    totalHours.text(`${newTotalHours} hrs`);
  }
}
function wrap() {
  const self = d3.select(this);
  const text = self.text();
  if (text.length > 18) {
    self.text(text.slice(0, 15) + '...');
  }
}
// Sunburst chart using D3.js. The chart is interactive and allows the user to zoom in and out of different sections of the chart. The component takes in a `data` prop which is used to generate the chart. The `partition` function is used to create a hierarchical layout of the data, which is then used to generate the chart.
// The `color` variable is created using the `d3.scaleOrdinal` function, which generates a color scale based on the number of children in the data. The `root` variable is used to store the hierarchical layout of the data, and the `current` property is added to each node in the hierarchy to keep track of the current state of the chart.
// The `svg` variable is used to create an SVG element that is appended to the `containerRef` element. The `g` variable is used to create a group element that is translated to the center of the SVG element. The `path` variable is used to create a path element for each node in the hierarchy, and the `fill` property is set based on the color scale generated earlier. The `fill-opacity` property is set based on whether the node is currently visible or not, and the `pointer-events` property is set to either `auto` or `none` based on whether the node is currently visible or not.
// The `label` variable is used to create a text element for each node in the hierarchy, and the `fill-opacity` property is set based on whether the node is currently visible or not. The `parent` variable is used to create a circle element that is used to zoom out of the chart when clicked.
// The `clicked` function is used to handle the zooming functionality of the chart. It takes in an event and a node, and updates the `parent` variable to the parent of the current node. It then updates the `target` property of each node in the hierarchy to the new state of the chart. Finally, it transitions the chart to the new state using the `transition` function.
// To improve the readability of the code, the `arcVisible`, `labelVisible`, and `labelTransform` functions could be moved to a separate file or function. Additionally, the `path` and `label` variables could be combined into a single variable to reduce duplication. To improve performance, the `color` scale could be memoized to prevent it from being regenerated on every render.
export const SunburstZoomChart = ({ data, handleDownload }) => {
  const [hoveredElement, setHoveredElement] = useState();
  const svgRef = useRef();
  useEffect(() => {
    const width = svgRef.current.clientWidth;
    const radius = width / 6;
    const arc = d3
      .arc()
      .startAngle((d) => d.x0)
      .endAngle((d) => d.x1)
      .padAngle((d) => Math.min((d.x1 - d.x0) / 2, 0.005))
      .padRadius(radius * 1.5)
      .innerRadius((d) => d.y0 * radius)
      .outerRadius((d) => Math.max(d.y0 * radius, d.y1 * radius - 1));
    function arcVisible(d) {
      return d.y1 <= 3 && d.y0 >= 1 && d.x1 > d.x0;
    }
    function labelVisible(d) {
      return d.y1 <= 3 && d.y0 >= 1 && (d.y1 - d.y0) * (d.x1 - d.x0) > 0.03;
    }
    function labelTransform(d) {
      const x = (((d.x0 + d.x1) / 2) * 180) / Math.PI;
      const y = ((d.y0 + d.y1) / 2) * radius;
      return `rotate(${x - 90}) translate(${y},0) rotate(${x < 180 ? 0 : 180})`;
    }
    const partition = (data) => {
      const root = d3
        .hierarchy(data)
        .sum((d) => d.value)
        .sort((a, b) => b.value - a.value);
      return d3.partition().size([2 * Math.PI, root.height + 1])(root);
    };
    d3.format(',d');
    const root = partition(data);
    const color = d3.scaleOrdinal(
      d3.quantize(d3.interpolateRainbow, data.children.length + 1),
    );
    root.each((d) => (d.current = d));
    d3.select('#SunburstZoomChart').remove();
    const svg = d3
      .select(svgRef.current)
      .append('svg')
      .attr('id', 'SunburstZoomChart')
      .attr('viewBox', [0, 0, width, width])
      .style('font-family', 'Roboto')
      .style('font-weight', '100')
      .style('font-size', '10px');
    const g = svg.append('g').attr('transform', `translate(${width / 2},${width / 2})`);
    const path = g
      .append('g')
      .selectAll('path')
      .data(root.descendants().slice(1))
      .join('path')
      .attr('fill', (d) => {
        while (d.depth > 1) d = d.parent;
        return color(d.data.name);
      })
      .attr('fill-opacity', (d) => (arcVisible(d.current) ? (d.children ? 0.6 : 0.4) : 0))
      .attr('pointer-events', (d) => (arcVisible(d.current) ? 'auto' : 'none'))
      .attr('d', (d) => arc(d.current));
    path
      .filter((d) => d.children)
      .style('cursor', 'pointer')
      .on('click', clicked);
    // create a total hours element
    const totalHours = g
      .append('text')
      .attr('x', 0)
      .attr('y', 0)
      .attr('text-anchor', 'middle')
      .attr('dominant-baseline', 'central')
      .attr('class', 'total-hours');
    // calculate the total hours
    updateTotalHours(root, totalHours);
    // add mouseover event to show/hide the tooltip
    path.on('mouseover', function (_event, d) {
      setHoveredElement(d);
    });
    path.on('mouseout', function (_event, d) {
      setHoveredElement(null);
    });
    const label = g
      .append('g')
      .attr('pointer-events', 'none')
      .attr('text-anchor', 'middle')
      .style('user-select', 'none')
      .selectAll('text')
      .data(root.descendants().slice(1))
      .join('text')
      .attr('dy', '0.35em')
      .attr('fill-opacity', (d) => +labelVisible(d.current))
      .attr('transform', (d) => labelTransform(d.current))
      .text((d) => d.data.name)
      .each(wrap);
    const parent = g
      .append('circle')
      .datum(root)
      .attr('r', radius)
      .attr('fill', 'none')
      .attr('pointer-events', 'all')
      .on('click', clicked);
    function clicked(event, p) {
      parent.datum(p.parent || root);
      root.each(
        (d) =>
          (d.target = {
            x0: Math.max(0, Math.min(1, (d.x0 - p.x0) / (p.x1 - p.x0))) * 2 * Math.PI,
            x1: Math.max(0, Math.min(1, (d.x1 - p.x0) / (p.x1 - p.x0))) * 2 * Math.PI,
            y0: Math.max(0, d.y0 - p.depth),
            y1: Math.max(0, d.y1 - p.depth),
          }),
      );
      const t = g.transition().duration(750);
      // Transition the data on all arcs, even the ones that aren’t visible,
      // so that if this transition is interrupted, entering arcs will start
      // the next transition from the desired position.
      path
        .transition(t)
        .tween('data', (d) => {
          const i = d3.interpolate(d.current, d.target);
          return (t) => (d.current = i(t));
        })
        .filter(function (d) {
          return +this.getAttribute('fill-opacity') || arcVisible(d.target);
        })
        .attr('fill-opacity', (d) =>
          arcVisible(d.target) ? (d.children ? 0.6 : 0.4) : 0,
        )
        .attr('pointer-events', (d) => (arcVisible(d.target) ? 'auto' : 'none'))

        .attrTween('d', (d) => () => arc(d.current));
      label
        .filter(function (d) {
          return +this.getAttribute('fill-opacity') || labelVisible(d.target);
        })
        .transition(t)
        .attr('fill-opacity', (d) => +labelVisible(d.target))
        .attrTween('transform', (d) => () => labelTransform(d.current));
      // calculate the new total hours
      updateTotalHours(p, totalHours);
    }
  }, [data]);
  return (
    <>
      <Tooltip
        title={
          hoveredElement ? (
            <div>
              {hoveredElement
                .ancestors()
                .map((d) => d.data.name)
                .reverse()
                .map((name) => (
                  <div key={name}>{name}</div>
                ))}
              {hoveredElement.value} hrs / {hoveredElement.parent.value} hrs
              <br />
              {((hoveredElement.value / hoveredElement.parent.value) * 100.0).toFixed(2)}%
            </div>
          ) : (
            ''
          )
        }
        followCursor
        open={Boolean(hoveredElement)}
        disableHoverListener
      >
        <Box ref={svgRef} className="chart">
          <Button className="chart-download-button" onClick={handleDownload}>
            <FileDownload />
          </Button>
        </Box>
      </Tooltip>
    </>
  );
};
