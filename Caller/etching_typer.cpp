//--------------------------------------------------------------------
// Copyright 2020. Bioinformatic and Genomics Lab.
// Hanyang University, Seoul, Korea
// Coded by Jang-il Sohn (sohnjangil@gmail.com)
//--------------------------------------------------------------------

#include "my_vcf.hpp"
#include <string>
#include <iostream>
#include <fstream>
#include <map>
#include <set>
#include <vector>

void typer_usage(){
  std::cout << "Usage:  etching_typer  input.vcf  genome.fa.fai\n" ;
}


int main ( int argc , char ** argv ){
  if ( argc != 3 ){
  typer_usage();
  return 0;
  }
  
  std::string infile = argv[1];
  std::string index = argv[2];
  std::string outfile = infile.substr(0,infile.size()-3) + "etching_typer.vcf";

  std::string id;
  int length;

  std::string tmp;
  std::vector < std::string > metainfo;
  VCF_LINE vcf_line;
  VCF container;
  VCF container_SV;

  int count = 0 ;
  
  std::ifstream fin;
  fin.open( index.c_str() );
  while ( fin >> id ){
    fin >> length;
    container.id_ref_map[id] = count;
    container.ref_id_map[count] = id;
    count ++;
  }

  fin.close();
  fin.open( infile.c_str() );

  /////////////////////////////////////////////////////////////////
  //
  // Reading metainfo
  //

  bool is_etching = 0 ;

  while ( std::getline ( fin , tmp ) ){
    if ( tmp.substr(0,2) == "##" ){
      metainfo.push_back(tmp);
      if ( tmp.find("##source=ETCHING") != 0 ) is_etching = 1;
    }
    else break;
  }
  metainfo.push_back(tmp);

  
  /////////////////////////////////////////////////////////////////
  //
  // fill VCF container
  //

  while ( std::getline ( fin , tmp ) ){
    if ( is_etching) vcf_line.parse_etching(tmp);
    else vcf_line.parse(tmp);
    container.insert(vcf_line);
  }

  fin.close();


  /////////////////////////////////////////////////////////////////
  //
  // Add metainfo
  //

  // found = 0 ;
  for ( std::size_t i = 0 ; i < metainfo.size() - 2 ; i ++ ){
    container.metainfo += metainfo[i] + "\n";
  }

  container.metainfo += metainfo[metainfo.size()-2];
  container.header = metainfo[metainfo.size()-1];

  
  /////////////////////////////////////////////////////////////////
  //
  // Typing SVs
  //
  
  container_SV = typing_SV ( container );
  
  /////////////////////////////////////////////////////////////////
  //
  // print result
  //
  
  container_SV.fwrite(outfile);
  return 0;
}
